-- all angles are in radians from east
RADAR_RANGE = 6400

BASE_GPS_X = 0
BASE_GPS_Y = 0
YAW = 0
PITCH = 0
ROLL = 0
ZOOM = 0

TARGETS = {}

function CreateTarget(x, y, z, distance, lastUpdate)
    return {
        x = x,
        y = y,
        z = z,
        distance = distance,
        lastUpdate = lastUpdate
    }
end

function GPSDistance3D(t1, t2)
    local dx = t1.x - t2.x
    local dy = t1.y - t2.y
    local dz = t1.z - t2.z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

DELTA = 20
function ProcessNewTarget(newTarget)
    for i, target in pairs(TARGETS) do
        if (GPSDistance3D(target, newTarget) < DELTA) then
            TARGETS[i] = CreateTarget(
                target.x + ((target.x - newTarget.x) / 10),
                target.y + ((target.y - newTarget.y) / 10),
                target.z + ((target.z - newTarget.z) / 2),
                (target.distance + newTarget.distance) / 2,
                target.lastUpdate - 1
            )
            return
        end
    end
    table.insert(TARGETS, newTarget)
end

function ConvertToLocalCoordinates(x, y, z)
    local rotMatrix = {
        {
            (math.cos(PITCH) * math.cos(YAW)),
            (math.cos(PITCH) * math.sin(YAW) * math.sin(ROLL)) - (math.sin(PITCH) * math.cos(ROLL)),
            (math.cos(PITCH) * math.sin(YAW) * math.cos(ROLL)) + (math.sin(PITCH) * math.sin(ROLL)),
        },
        {
            (math.sin(PITCH) * math.cos(YAW)),
            (math.sin(PITCH) * math.sin(YAW) * math.sin(ROLL)) + (math.cos(PITCH) * math.cos(ROLL)),
            (math.sin(PITCH) * math.sin(YAW) * math.cos(ROLL)) - (math.cos(PITCH) * math.sin(ROLL)),
        },
        {
            ((-1) * math.sin(YAW)),
            (math.cos(YAW) * math.sin(ROLL)),
            (math.cos(YAW) * math.cos(ROLL))
        },
    }

    return {
        x = (rotMatrix[1][1] * x) + (rotMatrix[1][2] * y) + (rotMatrix[1][3] * z),
        y = (rotMatrix[2][1] * x) + (rotMatrix[2][2] * y) + (rotMatrix[2][3] * z),
        z = (rotMatrix[3][1] * x) + (rotMatrix[3][2] * y) + (rotMatrix[3][3] * z),
    }
end

TIMEOUT = 60 * 5
function onTick()
    BASE_GPS_X = input.getNumber(27)
    BASE_GPS_Y = input.getNumber(28)
    YAW = math.fmod((input.getNumber(29) + 1.25) * 2 * math.pi, 2 * math.pi)
    PITCH = input.getNumber(30) * 2 * math.pi
    ROLL = input.getNumber(31) * 2 * math.pi
    ZOOM = input.getNumber(32)

    for i = 1, 5 do
        if (input.getBool(i)) then
            local distance = input.getNumber((i * 4) - 3)
            local azimuth = (math.pi / 2) + (2 * math.pi * input.getNumber((i * 4) - 2))
            local elevation = (math.pi / 2) + (math.pi * input.getNumber((i * 4) - 1))

            -- convert xyz from polar coordinates
            local x = distance * math.cos(azimuth) * math.cos(elevation)
            local y = distance * math.sin(azimuth) * math.cos(elevation)
            local z = distance * math.sin(elevation)

            local localXYZ = ConvertToLocalCoordinates(x, y, z)

            async.httpGet(6942, "/INFO?x=" .. tostring(x)
                .. "&y=" .. tostring(y)
                .. "&z=" .. tostring(z)
                .. "&localX=" .. tostring(localXYZ.x)
                .. "&localY=" .. tostring(localXYZ.y)
                .. "&localZ=" .. tostring(localXYZ.z)
                .. "&distance=" .. tostring(distance)
                .. "&azimuth=" .. tostring(azimuth)
                .. "&elevation=" .. tostring(elevation)
                .. "&yaw=" .. tostring(YAW)
                .. "&pitch=" .. tostring(PITCH)
                .. "&roll=" .. tostring(ROLL)
                .. "&zoom=" .. tostring(ZOOM)
            )

            ProcessNewTarget(CreateTarget(
                localXYZ.x + BASE_GPS_X,
                localXYZ.y + BASE_GPS_Y,
                localXYZ.z,
                distance,
                0
            ))
        else
            break
        end
    end

    for i, target in pairs(TARGETS) do
        if (target.lastUpdate > TIMEOUT) then
            table.remove(TARGETS, i)
        else
            TARGETS[i].lastUpdate = target.lastUpdate + 1
        end
    end
end

function onDraw()
    local w = screen.getWidth()
    local h = screen.getHeight()

    screen.setColor(255, 255, 255)
    screen.drawText(0, 0, "ZOOM: " .. tostring(math.ceil(ZOOM)))
    screen.drawText(0, 8, "TRACKING " .. tostring(#TARGETS) .. " TANGOS")
    local maxDistance = 0
    for _, target in pairs(TARGETS) do
        if (target.distance > maxDistance) then
            maxDistance = target.distance
        end
    end
    screen.drawText(0, 16, "MAX DISTANCE: " .. tostring(math.ceil(maxDistance)) .. "m")
    screen.drawText(w / 2, 4, "N")
    screen.drawText(w / 2, h - 8, "S")
    screen.drawText(4, h / 2, "W")
    screen.drawText(w - 8, h / 2, "E")

    for _, target in pairs(TARGETS) do
        local mapX, mapY = map.mapToScreen(BASE_GPS_X, BASE_GPS_Y, ZOOM, w, h, target.x, target.y)
        screen.setColor(255, 0, 0)
        screen.drawCircle(mapX, mapY, 1)
    end
end
