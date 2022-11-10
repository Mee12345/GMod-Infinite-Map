// metatable fuckery
local EntityMT = FindMetaTable("Entity")
local VehicleMT = FindMetaTable("Vehicle")
local PhysObjMT = FindMetaTable("PhysObj")
local PlayerMT = FindMetaTable("Player")
local NextBotMT = FindMetaTable("NextBot")
local CTakeDamageInfoMT = FindMetaTable("CTakeDamageInfo")

EntityMT.InfMap_GetPos = EntityMT.InfMap_GetPos or EntityMT.GetPos
function EntityMT:GetPos()
	if !self.CHUNK_OFFSET or !LocalPlayer().CHUNK_OFFSET then return self:InfMap_GetPos(pos) end
	return InfMap.unlocalize_vector(self:InfMap_GetPos(), self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end

EntityMT.InfMap_LocalToWorld = EntityMT.InfMap_LocalToWorld or EntityMT.LocalToWorld
function EntityMT:LocalToWorld(pos)
	if !self.CHUNK_OFFSET or !LocalPlayer().CHUNK_OFFSET then return self:InfMap_LocalToWorld(pos) end
	return InfMap.unlocalize_vector(self:InfMap_LocalToWorld(pos), self.CHUNK_OFFSET - LocalPlayer().CHUNK_OFFSET)
end
local clamp = math.Clamp
local function clamp_vector(pos, max)
	return Vector(clamp(pos[1], -max, max), clamp(pos[2], -max, max), clamp(pos[3], -max, max))
end

EntityMT.InfMap_SetPos = EntityMT.InfMap_SetPos or EntityMT.SetPos
function EntityMT:SetPos(pos)
	local pos = clamp_vector(pos, 2^14)
	return self:InfMap_SetPos(pos)
end


// traces shouldnt appear when shot from other chunks
hook.Add("EntityFireBullets", "infmap_detour", function(ent, data)
	if ent.CHUNK_OFFSET != LocalPlayer().CHUNK_OFFSET then
		data.Tracer = 0
		return true
	end
end)

//recieve networked sounds
net.Receive( "inf_entsound", function( len, ply )
	local soundTable = net.ReadTable()
	local ent = soundTable.Entity
	if LocalPlayer().CHUNK_OFFSET != ent.CHUNK_OFFSET then //this does not properly support moving chunks with continuous sounds playing e.g. thrusters! (or explosions?)
		soundTable.Volume = 0 //set volume to zero if not in chunk, otherwise continuous sounds will not update to players outside chunk
	end

	ent:EmitSound(soundTable.OriginalSoundName,soundTable.SoundLevel,soundTable.Pitch,soundTable.Volume,soundTable.Channel,soundTable.Flags,soundTable.DSP)
end )

/*********** Client Entity Metatable *************/

EntityMT.InfMap_SetRenderBounds = EntityMT.InfMap_SetRenderBounds or EntityMT.SetRenderBounds
function EntityMT:SetRenderBounds(min, max, add)
	if self.RENDER_BOUNDS then
		self.RENDER_BOUNDS = {min, max}
	end
	return self:InfMap_SetRenderBounds(min, max, add)
end

/*********** Client Other *************/

// traceline
// faster lookup
local istable = istable
local IsEntity = IsEntity
local function modify_trace_data(orig_data, trace_func, extra)
	local data = {}
	for k, v in pairs(orig_data) do
		data[k] = v
	end
	local start_offset = LocalPlayer().CHUNK_OFFSET or Vector()
	// #2 create filter and only hit entities in your chunk
	local old_filter = data.filter
	if !old_filter then 
		data.filter = function(e) 
			return e.CHUNK_OFFSET == start_offset
		end
	elseif IsEntity(old_filter) then // rip efficiency
		data.filter = function(e)
			return e.CHUNK_OFFSET == start_offset and e != old_filter
		end 
	elseif istable(old_filter) then	
		data.filter = function(e)
			for i = 1, #old_filter do 
				if e == old_filter[i] then 
					return false
				end 
			end
			return e.CHUNK_OFFSET == start_offset
		end
	else // must be function
		data.filter = function(e)
			return old_filter(e) and e.CHUNK_OFFSET == start_offset
		end
	end
	local hit_data = trace_func(data, extra)
	local hit_ent = hit_data.Entity
	if hit_ent and hit_ent:IsValid() and hit_ent:GetClass() == "infmap_terrain_collider" then
		hit_data.Entity = game.GetWorld()
	end
	return hit_data
end
// traceline
InfMap.TraceLine = InfMap.TraceLine or util.TraceLine
function util.TraceLine(data)
	return modify_trace_data(data, InfMap.TraceLine)
end
// hull traceline
InfMap.TraceHull = InfMap.TraceHull or util.TraceHull
function util.TraceHull(data)
	return modify_trace_data(data, InfMap.TraceHull)
end
// entity traceline
InfMap.TraceEntity = InfMap.TraceEntity or util.TraceEntity
function util.TraceEntity(data, ent)
	return modify_trace_data(data, InfMap.TraceEntity, ent)
end
