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
    local function RotationMatrix(yaw, pitch, roll)
        local alpha = pitch
        local beta = yaw
        local gamma = roll
        return {
            { math.cos(alpha) * math.cos(beta),
                math.cos(alpha) * math.sin(beta) * math.sin(gamma) - math.sin(alpha) * math.cos(gamma),
                math.cos(alpha) * math.sin(beta) * math.cos(gamma) + math.sin(alpha) * math.sin(gamma) },
            { math.sin(alpha) * math.cos(beta),
                math.sin(alpha) * math.sin(beta) * math.sin(gamma) + math.cos(alpha) * math.cos(gamma),
                math.sin(alpha) * math.sin(beta) * math.cos(gamma) - math.cos(alpha) * math.sin(gamma) },
            { -math.sin(beta), math.cos(beta) * math.sin(gamma), math.cos(beta) * math.cos(gamma) },
            mul = function(self, v)
                return {
                    X = self[1][1] * v.X + self[1][2] * v.Y + self[1][3] * v.Z,
                    Y = self[2][1] * v.X + self[2][2] * v.Y + self[2][3] * v.Z,
                    Z = self[3][1] * v.X + self[3][2] * v.Y + self[3][3] * v.Z
                }
            end
        }
    end

    return RotationMatrix(YAW, PITCH, ROLL):mul(target)
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
