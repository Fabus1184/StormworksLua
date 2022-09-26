BASE_GPS_X = 0
BASE_GPS_Y = 0
BASE_HEADING_ABSOLUTE = 0
RADAR_HEADING_RELATIVE = 0
ZOOM = 0
RADAR_RANGE = 10000

function onTick()
    BASE_GPS_X = input.getNumber(1)
    BASE_GPS_Y = input.getNumber(2)
    BASE_HEADING_ABSOLUTE = math.fmod((input.getNumber(3) + 1.25) * 2 * math.pi, 2 * math.pi)
    RADAR_HEADING_RELATIVE = (-2) * math.pi * math.fmod(input.getNumber(4), 1)
    ZOOM = input.getNumber(5)
end

function onDraw()
    local w = screen.getWidth()
    local h = screen.getHeight()

    screen.drawMap(BASE_GPS_X, BASE_GPS_Y, ZOOM)

    screen.setColor(0, 255, 0)
    local mapX, mapY = map.mapToScreen(BASE_GPS_X, BASE_GPS_Y, ZOOM, w, h, BASE_GPS_X, BASE_GPS_Y)
    screen.drawRect(mapX - 1, mapY + 1, 3, 3)

    for i = 0, 20 do
        screen.setColor(0, 255, 0, 255 - (i * 255 / 20))
        local angle = BASE_HEADING_ABSOLUTE + RADAR_HEADING_RELATIVE + (i * math.pi / 360)
        screen.drawLine(
            w / 2, h / 2,
            (w / 2) + ((RADAR_RANGE / 2 / ZOOM) * math.cos(angle)),
            (h / 2) - ((RADAR_RANGE / 2 / ZOOM) * math.sin(angle))
        )
    end

    screen.setColor(0, 0, 0)
    screen.drawLine(
        w / 2, h / 2,
        (w / 2) + (10 * math.cos(BASE_HEADING_ABSOLUTE)),
        (h / 2) - (10 * math.sin(BASE_HEADING_ABSOLUTE))
    )
end
