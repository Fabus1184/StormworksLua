-- all angles are in radians from east
RADAR_RANGE = 6400

BASE_GPS_X = 0
BASE_GPS_Y = 0
YAW = 0
PITCH = 0
ROLL = 0
ZOOM = 0

TARGETS = {}

function ConvertToLocalCoordinates(target)
    local rotMatrix = {
        { math.cos(PITCH) * math.cos(YAW),
            math.cos(PITCH) * math.sin(YAW) * math.sin(ROLL) - math.sin(PITCH) * math.cos(ROLL),
            math.cos(PITCH) * math.sin(YAW) * math.cos(ROLL) + math.sin(PITCH) * math.sin(ROLL) },
        { math.sin(PITCH) * math.cos(YAW),
            math.sin(PITCH) * math.sin(YAW) * math.sin(ROLL) + math.cos(PITCH) * math.cos(ROLL),
            math.sin(PITCH) * math.sin(YAW) * math.cos(ROLL) - math.cos(PITCH) * math.sin(ROLL) },
        { -math.sin(YAW), math.cos(YAW) * math.sin(ROLL), math.cos(YAW) * math.cos(ROLL) },
    }

    return {
        X = (rotMatrix[1][1] * target.X) + (rotMatrix[1][2] * target.Y) + (rotMatrix[1][3] * target.Z),
        Y = (rotMatrix[2][1] * target.X) + (rotMatrix[2][2] * target.Y) + (rotMatrix[2][3] * target.Z),
        Z = (rotMatrix[3][1] * target.X) + (rotMatrix[3][2] * target.Y) + (rotMatrix[3][3] * target.Z)
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

    for i = 1, 6 do
        if (input.getBool(i)) then
            local distance = input.getNumber((i * 4))
            local azimuth = (math.pi / 2) + (2 * math.pi * input.getNumber((i * 4) + 1))
            local elevation = (math.pi / 2) + (math.pi * input.getNumber((i * 4) + 2))

            local Z = math.sin(elevation) * distance
            local Y = math.sin(-azimuth) * distance
            local X = math.sqrt((distance ^ 2) - (Y ^ 2) - (Z ^ 2))

            local target = ConvertToLocalCoordinates({
                X = X,
                Y = Y,
                Z = Z
            })
            target.X = target.X + BASE_GPS_X
            target.Y = target.Y + BASE_GPS_Y
            target.lastUpdate = 0
            target.distance = distance

            table.insert(TARGETS, target)
        else
            break
        end
    end

    for i, target in pairs(TARGETS) do
        if (target.lastUpdate > TIMEOUT) then
            table.remove(TARGETS, i)
        else
            target.lastUpdate = target.lastUpdate + 1
        end
    end
end

function onDraw()
    local w = screen.getWidth()
    local h = screen.getHeight()

    for _, target in pairs(TARGETS) do
        local mapX, mapY = map.mapToScreen(BASE_GPS_X, BASE_GPS_Y, ZOOM, w, h, target.X, target.Y)
        screen.setColor(255, 0, 0)
        screen.drawCircle(mapX, mapY, 1)
    end

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

    local maxZ = 0
    for _, target in pairs(TARGETS) do
        if (target.Z > maxZ) then
            maxZ = target.Z
        end
    end
    screen.drawText(0, 24, "MAX ALTITUDE: " .. tostring(math.ceil(maxZ)) .. "m")
end
