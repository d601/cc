--------------------------------------------------------------------------------
-- Vector3
--------------------------------------------------------------------------------

Vector3 = {}

function Vector3.new(x, y, z)
    v = {x = x, y = y, z = z}
    setmetatable(v, Vector3)
    v.__index = Vector3
    return v
end

function Vector3.zero()
    return Vector3.new(0, 0, 0)
end

function Vector3.__add(v1, v2)
    return Vector3.new(v1.x + v2.x, v1.y + v2.y, v1.z + v2.z)
end

function Vector3.__sub(v1, v2)
    return Vector3.new(v1.x - v2.x, v1.y - v2.y, v1.z - v2.z)
end


--------------------------------------------------------------------------------
-- TurtleManager
--------------------------------------------------------------------------------

-- Utility class that makes a bunch of turtle related things more convenient
-- - Automatically refuels before moving
-- - Can keep track of position without gps
-- - Can save/load position state

TurtleManager = {
    -- Instance
    position = Vector3.new(0, 0, 0),
    facing = 1,

    -- Static
    minimum_fuel_level = 100,
    displacement_vectors = {
        Vector3.new(1, 0, 0),
        Vector3.new(0, 1, 0),
        Vector3.new(-1, 0, 0),
        Vector3.new(0, -1, 0),

        Vector3.new(0, 0, 1),
        Vector3.new(0, 0, -1)
    },
    state_filename = "foostate"
}

function TurtleManager:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function TurtleManager:save()
    fh = io.open(self.state_filename .. "~", "w")
    fh:write(string.format("{x = %d, y = %d, z = %d, facing = %d}",
        self.position.x, self.position.y, self.position.z, self.facing))
    fh:close()
    fs.delete(self.state_filename)
    fs.move(self.state_filename .. "~", self.state_filename)
end

function TurtleManager:load()
    fh = io.open(self.state_filename, "r")
    state_string = fh:read()
    fh:close()
    state = loadstring("return " .. state_string)()
    self.position = Vector3.new(state.x, state.y, state.z)
    self.facing = state.facing
end

function TurtleManager:needs_refuelling()
    return turtle.getFuelLevel() < self.minimum_fuel_level
end

function TurtleManager:refuel_if_needed()
    if self:needs_refuelling() then
        turtle.select(2)
        while self:needs_refuelling() do
            turtle.refuel(1)
            os.sleep(0.5)
        end
    end
end

function TurtleManager:_move(move_function, displacement)
    self:refuel_if_needed()
    result = turtle[move_function]()
    if result then
        self.position = self.position + displacement
    end
    return result
end

function TurtleManager:forward()
    self:_move("forward", self.displacement_vectors[self.facing])
end

function TurtleManager:back()
    self:_move("back", Vector3.zero() - self.displacement_vectors[self.facing])
end

function TurtleManager:up()
    self:_move("up", self.displacement_vectors[5])
end

function TurtleManager:down()
    self:_move("down", self.displacement_vectors[6])
end

function TurtleManager:turn_left()
    turtle.turnLeft()
    self.facing = ((self.facing - 2) % 4) + 1
end

function TurtleManager:turn_right()
    turtle.turnRight()
    self.facing = math.max(((self.facing + 1) % 5), 1)
end

--------------------------------------------------------------------------------
-- TreeFarm
--------------------------------------------------------------------------------

TreeFarm = {}

function TreeFarm:new(length, spacing)
    o = {
        length = length,
        spacing = spacing,
        tm = TurtleManager:new()
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function TreeFarm:_plant()
    if turtle.detectDown() then
        return
    end
    turtle.select(1)
    if (turtle.getItemCount() == 0) then
        print("Please insert saplings into slot 1.")
        while (turtle.getItemCount() == 0) do
            os.sleep(1)
        end
    end
    if (not turtle.placeDown()) then
        print("Something is obstructing planting. Please remove it.")
        while (not turtle.placeDown()) do
            os.sleep(1)
        end
        print("Detected removal of obstruction.")
    end
end

function TreeFarm:_harvest()
    current_z = self.tm.position.z

    -- Dig upwards while there are still more blocks
    while (turtle.detectUp()) do
        turtle.digUp()
        self.tm:up()
    end

    -- Go back to original position
    top_z = self.tm.position.z
    dz = top_z - current_z
    if (dz ~= 0) then
        for i = 1, dz, 1 do
            self.tm:down()
        end
    end

    -- Remove stump if it's there
    turtle.select(1)
    if (turtle.detectDown() and not turtle.compareDown()) then
        print("Found stump")
        turtle.digDown()
    end
end

function TreeFarm:_farm_loop()
    for i = 1, self.length, 1 do
        if (turtle.detect()) then
            turtle.dig()
        end

        self.tm:forward()

        if (turtle.detectDown()) then
            turtle.select(1)
            if (not turtle.compareDown()) then
                print("Found something where a sapling should be")
                self:_harvest() -- make sure this works how it should from here
            end
        end

        self:_plant()

        if ((i ~= self.length) and (self.spacing ~= 0)) then
            for j = 1, self.spacing, 1 do
                self.tm:forward()
                if (turtle.detectDown()) then
                    self:_harvest()
                end
            end
        end
    end

    self.tm:forward()
    self.tm:turn_left()
    self.tm:turn_left()

    while (not turtle.detect()) do
        os.sleep(1)
    end
end

function TreeFarm:start()
    while true do
        self:_farm_loop()
    end
end
    
tf = TreeFarm:new(4, 2)
tf:start()
