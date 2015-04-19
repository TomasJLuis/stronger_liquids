local load_time_start = os.clock()

local function table_icontains(t, v)
	for i = 1,#t do
		if t[i] == v then
			return true
		end
	end
	return false
end

local allowed_drawtypes = {"plantlike", "torchlike", "signlike", "raillike", "nodebox", "mesh"}
-- FIXME is this the best way to find out if a node can be flooded or not?

local flow_nodes
local function get_flow_nodes()
	flow_nodes = {}
	for n,i in pairs(minetest.registered_nodes) do
		if table_icontains(allowed_drawtypes, i.drawtype)
			then
			local typ
			if i.buildable_to then
				typ = 1
			else
				local groups = i.groups
				if groups
				and groups.attached_node
				and groups.attached_node > 0 then
					typ = 2
				end
			end
			if typ then
				local sounds,sound = i.sounds
				if sounds then
					sound = sounds.dug
				end
				flow_nodes[n] = {typ, sound}
			end
		end
	end
end

local function flow(pos, name)
	local name = name or minetest.get_node(pos).name
	local node = flow_nodes[name]
	if not node then
		return
	end
	if node[2] then
		minetest.sound_play(node[2], {pos=pos})
	end
	local typ = node[1]
	if typ == 1 then
		minetest.remove_node(pos)
		return true
	elseif typ == 2 then
		for _,item in pairs(minetest.get_node_drops(name)) do
			minetest.add_item(pos, item)
		end
		minetest.remove_node(pos)
		return true
	end
end

local function update_liquids(pos, node, liquid)
	local liquid_name = liquid or node.name
	local liquid_type = minetest.registered_nodes[liquid_name].liquidtype
	local param2 = node.param2

	if liquid_type == "flowing" and (param2 > 7 or param2 == 0) then return end

	pos.y = pos.y-1
	local nd = minetest.get_node(pos).name
	if nd ~= liquid_name and flow(pos, nd) then
		return
	end

	pos.y = pos.y+1
	for j = -1,1,2 do
		for _,i in ipairs({
			{0,j},
			{j,0},
		}) do
			pos.x = pos.x+i[1]
			pos.z = pos.z+i[2]
			if flow(pos) then return end
			pos.x = pos.x-i[1]
			pos.z = pos.z-i[2]
			if flow(pos) then return end
		end
	end
end

minetest.register_abm({
	nodenames = {"group:liquid"},
	interval = 3,
	chance = 1,
	action = function(pos, node)
		if not flow_nodes then
			get_flow_nodes()
		end
		update_liquids(pos, node)
	end
})

minetest.register_abm({
	nodenames = {"default:water_flowing"},
	interval = 1.8,
	chance = 1.5,
	action = function(pos, node, active_object_count, active_object_count_wider)
		minetest.sound_play("water", {pos = pos, gain = 0.125, max_hear_distance = 4})
	end
})

minetest.register_abm({
	nodenames = {"default:lava_source"},
	interval = 2,
	chance = 2,
	action = function(pos, node, active_object_count, active_object_count_wider)
		minetest.sound_play("lava", {pos = pos, gain = 0.125, max_hear_distance = 8})
		if math.random(1,13) == 8 then
			local rnd = math.random(0,1)*-1
			minetest.add_particle(pos, {x=0.1*rnd, y=0.8, z=-0.1*rnd}, {x=-0.5*rnd, y=0.2, z=0.5*rnd}, 1.7,	1.2, true, "lava_particle.png")
		end
	end
})

minetest.log("info", string.format("[stronger_liquids] loaded after ca. %.2fs", os.clock() - load_time_start))

