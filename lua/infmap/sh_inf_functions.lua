// useful functions used throughout the lua

function InfMap.in_chunk(pos, size) 
	local cs = size or InfMap.chunk_size
	return !(pos[1] <= -cs or pos[1] >= cs or pos[2] <= -cs or pos[2] >= cs or pos[3] <= -cs or pos[3] >= cs)
end

function InfMap.localize_vector(pos, size) 
	local cs = size or InfMap.chunk_size
	local cs_double = cs * 2

	local floor = math.floor
	local cox = floor((pos[1] + cs) / cs_double)
	local coy = floor((pos[2] + cs) / cs_double)
	local coz = floor((pos[3] + cs) / cs_double)
	local chunk_offset = Vector(cox, coy, coz)

	local chunk_size_vec = Vector(1, 1, 1) * cs

	// offset vector so coords are 0 to x*2 instead of -x to x
	pos = pos + chunk_size_vec

	// wrap coords
	pos[1] = pos[1] % cs_double
	pos[2] = pos[2] % cs_double
	pos[3] = pos[3] % cs_double

	// add back offset
	pos = pos - chunk_size_vec

	return pos, chunk_offset
end

function InfMap.unlocalize_vector(pos, chunk)
	return (chunk or Vector()) * InfMap.chunk_size * 2 + pos
end

// self explainatory
function InfMap.intersect_box(min_a, max_a, min_b, max_b) 
	local x_check = max_b[1] < min_a[1] or min_b[1] > max_a[1]
	local y_check = max_b[2] < min_a[2] or min_b[2] > max_a[2]
	local z_check = max_b[3] < min_a[3] or min_b[3] > max_a[3]
	return !(x_check or y_check or z_check)
end

// all the classes that are useless
InfMap.filter = {
	infmap_clone = true,
	physgun_beam = true,
	worldspawn = true,
	gmod_hands = true,
	info_particle_system = true,
	phys_spring = true,
	predicted_viewmodel = true,
	env_projectedtexture = true,
	keyframe_rope = true,
	hl2mp_ragdoll = true,
	env_skypaint = true,
	shadow_control = true,
	player_pickup = true,
	env_sun = true,
	info_player_start = true,
	scene_manager = true,
	ai_network = true,
	bodyque = true,
	gmod_gamerules = true,
	player_manager = true,
	soundent = true,
	env_flare = true,
	_firesmoke = true,
	func_brush = true,
	logic_auto = true,
	light_environment = true,
	env_laserdot = true,
	env_smokestack = true,
	env_rockettrail = true,
	rpg_missile = true,
	gmod_safespace_interior = true,
	sizehandler = true,
	player_pickup = true,
	phys_spring = true,
	crossbow_bolt = true,
}

// classes that should not be picked up by physgun
InfMap.disable_pickup = {
	infmap_clone = true,
}

function InfMap.filter_entities(e)
	if InfMap.filter[e:GetClass()] then return true end
	if e:EntIndex() == 0 then return true end
	if SERVER and e:IsConstraint() then return true end
	//if !e.GetModelRenderBounds and !e:GetModelRenderBounds() then return true end

	return false
end

// code edited from starfallex
function InfMap.get_all_constrained(main_ent)
	local entity_lookup = {}
	local entity_table = {}
	local function recursive_find(ent)
		if entity_lookup[ent] then return end
		entity_lookup[ent] = true
		if ent:IsValid() then
			entity_table[#entity_table + 1] = ent
			local constraints = constraint.GetTable(ent)
			for k, v in pairs(constraints) do
				if v.Ent1 then recursive_find(v.Ent1) end
				if v.Ent2 then recursive_find(v.Ent2) end
			end

			//local parent = ent:GetParent()
			//if parent then recursive_find(parent) end
			//for k, child in pairs(ent:GetChildren()) do
			//	if child:IsPlayer() then continue end
			//	recursive_find(child)
			//end
		end
	end
	recursive_find(main_ent)

	return entity_table
end

// code edited from starfallex
function InfMap.get_all_parents(main_ent)
	local entity_lookup = {}
	local entity_table = {}
	local function recursive_find(ent)
		if entity_lookup[ent] then return end
		entity_lookup[ent] = true
		if ent:IsValid() then
			entity_table[#entity_table + 1] = ent
			local parent = ent:GetParent()
			if parent then recursive_find(parent) end
			for k, child in pairs(ent:GetChildren()) do
				if child:IsPlayer() then continue end
				recursive_find(child)
			end
		end
	end
	recursive_find(main_ent)

	return entity_table
end

local function constrained_invalid_filter(ent) 
	local phys_filter = false
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then
		phys_filter = !phys:IsMoveable()	// filter frozen props
	end
	return InfMap.filter_entities(ent) or (!ent:IsSolid() and ent:GetNoDraw()) or ent:GetParent():IsValid() or phys_filter or (ent:IsWeapon() and ent:GetOwner():IsValid())
end

function InfMap.constrained_status(ent)
	if ent.CONSTRAINED_MAIN != nil then
		return ent.CONSTRAINED_MAIN
	end

	// first pass, these entities arent valid
	if constrained_invalid_filter(ent) then 
		ent.CONSTRAINED_MAIN = false
		return ent.CONSTRAINED_MAIN
	end

	ent.CONSTRAINED_DATA = InfMap.get_all_constrained(ent)	// expensive function

	local ent_index = ent:EntIndex()
	for _, constrained_ent in ipairs(ent.CONSTRAINED_DATA) do
		if constrained_ent:IsPlayerHolding() then	// if player is holding, instead of basing it off the index base it off of the object that is being held
			ent.CONSTRAINED_MAIN = constrained_ent == ent
			return ent.CONSTRAINED_MAIN
		end

		if constrained_ent:EntIndex() < ent_index and !constrained_invalid_filter(constrained_ent) then 
			ent.CONSTRAINED_MAIN = false
			return ent.CONSTRAINED_MAIN
		end
	end

	ent.CONSTRAINED_MAIN = true
	return ent.CONSTRAINED_MAIN
end

function InfMap.reset_constrained_data(ent)
	ent.CONSTRAINED_DATA = nil 
	ent.CONSTRAINED_MAIN = nil
end

function InfMap.ezcoord(chunk)
	return chunk.x .. "," .. chunk.y .. "," .. chunk.z
end

InfMap.ent_list = {}

function InfMap.cleanup_track(ent)
	if not IsValid(ent) then return end
	if ent.CHUNK_OFFSET then
		local oldcoord = InfMap.ezcoord(ent.CHUNK_OFFSET)
		if not InfMap.ent_list[oldcoord] then return end // some how we made it all the way here
		InfMap.ent_list[oldcoord][ent:EntIndex()] = nil // scrub old entry
		if table.IsEmpty(InfMap.ent_list[oldcoord]) then InfMap.ent_list[oldcoord] = nil end // lil cleanup action here
	end
end

function InfMap.update_track(ent,chunk)
	if not IsValid(ent) then return end
	if ent.CHUNK_OFFSET then InfMap.cleanup_track(ent) end

	local curchunk = InfMap.ezcoord(chunk)

	if not InfMap.ent_list[curchunk] then InfMap.ent_list[curchunk] = {} end

	InfMap.ent_list[curchunk][ent:EntIndex()] = true

	PrintTable(InfMap.ent_list)
end