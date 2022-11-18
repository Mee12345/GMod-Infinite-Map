docs

How to make an infinite map
step 1: 
-create a map

step 2: 
-rename the map so it must has "infmap" as the second word in your map
-examples: gm_infmap_backrooms; gm_infmap_void; sb_infmap_planets, etc.

step 3: 
-make sure my infmap base is actually installed
-keep in mind, worldbrushes will repeat, remember the map isnt actually infinite.. it just teleports you


step 4 (skip if you dont care about custom map lua): 
-if you want custom lua follow this step
-custom lua in maps are handled seperately because you only want the lua to run when your map is initialized
-start by creating a new addon, make the file structure like this: "addons/myaddon/lua/infmap/yourmapname/.."
-add your lua files in there, don't worry about AddCSLuaFile(), it is handled automatically by my file loader
-ANY lua that is put in "addons/myaddon/lua/infmap/.." will run on EVERY INFINITE MAP, DONT PUT ANYTHING IN HERE!
-lua files that start with 'cl' and 'sh' are automatically addcsluafile'd
-make sure to put your custom lua HERE^ and not anywhere else, the lua ran in this file is ran before any other addon
is able to initialize
-The InfMap table and functions should already be initialized when your file is run


--- API ---
-most functions are detoured, things like SetPos should just work
-if you want the original function, put InfMap_ before calling it
-examples: Entity:SetPos--Entity:InfMap_SetPos, util.TraceLine--InfMap.TraceLine
-in order to avoid rounding errors I would suggest setting the position with InfMap_SetPos and setting which chunk it is in

FUNCTIONS:
InfMap.prop_update_chunk(Entity, Vector)->[nil]:
-Updates the chunk the entity is in, its real position is not altered in any way
-If done on client it will update to another chunk until the client's chunk is updated

InfMap.localize_vector(Vector, Number)->[Vector, Vector]:
-Input a vector, and it outputs the vector if it was "wrapped" in the same local coordinate space
-returns the wrapped position and the offsetted chunk
-Number is optional and by default is the chunk size

InfMap.unlocalize_vector(Vector, Vector)->[Vector]:
-Input a local position and a chunk and it returns the world position

InfMap.intersect_box(Vector, Vector, Vector, Vector)->[Boolean]:
-basic and efficent box intersection function
-first 2 vectors are the first box min and max
-last 2 vectors are the second box min and max

InfMap.filter_entities(Entity)->[Boolean]:
-Returns true if the entity will be ignored during chunk teleportation, cross chunk collision, and other factors

InfMap.get_all_constrained(Entity)->[Table]:
-Returns a table of all physically constrained entities (not including parents)

InfMap.get_all_parents(Entity)->[Table]:
-Returns a table of all parents connected to an entity

InfMap.constrained_status(Entity)->[Boolean]:
-Returns wheather the entity is the main parent entity
-Used internally

InfMap.reset_constrained_data(Entity)->[nil]:
-Sets constraint status to invalid
-Used internally

InfMap.in_chunk(Vector)->[Boolean]:
-Returns if a *LOCAL* position is inside of a chunk



VARIABLES:
InfMap.filter
-A table with all the useless entities in source
-Entities in this table are ignored and will not be wrapped in chunks

InfMap.chunk_size
-Size of each chunk, default is 10,000 but technically can be edited per map by just setting the variable
