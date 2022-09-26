-- all angles are in radians from east
RADAR_RANGE = 6400

BASE_GPS_X = 0
BASE_GPS_Y = 0
YAW = 0
PITCH = 0
ROLL = 0
ZOOM = 0

TARGETS = {}

function GPSDistance(t1, t2)
    local dx = t1.X - t2.X
    local dy = t1.Y - t2.Y
    local dz = t1.Z - t2.Z
    return math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
end

DELTA = 20
function ProcessNewTarget(newTarget)
    for _, target in pairs(TARGETS) do
        if (GPSDistance(target, newTarget) < DELTA) then
            target.X = (target.X + newTarget.X) / 2
            target.Y = (target.Y + newTarget.Y) / 2
            return
        end
    end
    table.insert(TARGETS, newTarget)
end

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

    for i = 1, 5 do
        if (input.getBool(i)) then
            local distance = input.getNumber((i * 4) - 3)
            local azimuth = (math.pi / 2) + (2 * math.pi * input.getNumber((i * 4) - 2))
            local elevation = (math.pi / 2) + (math.pi * input.getNumber((i * 4) - 1))

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

            ProcessNewTarget(target)
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
        local mapX, mapY = map.mapToScreen(BASE_GPS_X, BASE_GPS_Y, ZOOM, w, h, target.X, target.Y)
        screen.setColor(255, 0, 0)
        screen.drawRect(mapX, mapY, 2, 2)
    end
end
