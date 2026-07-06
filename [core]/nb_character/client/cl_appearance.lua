-- Appearance adatstruktúra alkalmazása a pedre, illetve alapértelmezett érték generálása.

NBChar = NBChar or {}

function NBChar.GetDefaultAppearance(model)
    local appearance = {
        model = model or Config.DefaultModel,
        headBlend = {
            shapeFirst = 0, shapeSecond = 0, shapeThird = 0,
            skinFirst = 0, skinSecond = 0, skinThird = 0,
            shapeMix = 0.5, skinMix = 0.5, thirdMix = 0.0
        },
        faceFeatures = {},
        headOverlays = {},
        eyeColor = 0,
        hair = { style = 0, color = 0, highlight = 0 },
        components = {},
        props = {}
    }

    for i = 1, Config.FaceFeatureCount do
        appearance.faceFeatures[i] = 0.0
    end

    for _, overlay in ipairs(Config.HeadOverlays) do
        appearance.headOverlays[tostring(overlay.id)] = {
            index = -1, opacity = 1.0, colorType = 1, colorIndex = 0, secondColorIndex = 0
        }
    end

    for _, slot in ipairs(Config.ClothingComponents) do
        appearance.components[tostring(slot)] = { drawable = 0, texture = 0 }
    end

    for _, slot in ipairs(Config.PropSlots) do
        appearance.props[tostring(slot)] = { drawable = -1, texture = 0 }
    end

    return appearance
end

-- Kiszámolja az összes drawable/texture darabszám-limitet az aktuális ped modellhez.
-- Ezt küldjük a NUI-nak, hogy tudja meddig lehet léptetni a next/prev gombokkal.
function NBChar.BuildLimits(ped)
    local limits = { components = {}, props = {} }

    for _, slot in ipairs(Config.ClothingComponents) do
        local drawableCount = GetNumberOfPedDrawableVariations(ped, slot)
        local textureCounts = {}
        for d = 0, math.max(drawableCount - 1, 0) do
            textureCounts[tostring(d)] = GetNumberOfPedTextureVariations(ped, slot, d)
        end
        limits.components[tostring(slot)] = { drawableCount = drawableCount, textureCounts = textureCounts }
    end

    for _, slot in ipairs(Config.PropSlots) do
        local drawableCount = GetNumberOfPedPropDrawableVariations(ped, slot)
        local textureCounts = {}
        for d = 0, math.max(drawableCount - 1, 0) do
            textureCounts[tostring(d)] = GetNumberOfPedPropTextureVariations(ped, slot, d)
        end
        limits.props[tostring(slot)] = { drawableCount = drawableCount, textureCounts = textureCounts }
    end

    limits.hairStyleCount = GetNumberOfPedDrawableVariations(ped, 2)

    return limits
end

-- Csak a ténylegesen megváltozott mezőt alkalmazza (nem az egész megjelenést),
-- hogy ne akadjon be a karakter minden apró csúszka-mozdításnál. A `changed`
-- egy JS-ből küldött hint string, pl. 'headBlend', 'faceFeature:3', 'hair',
-- 'overlay:4', 'eyeColor', 'component:8', 'prop:0'.
function NBChar.ApplyPartial(ped, appearance, changed)
    if not changed then
        NBChar.ApplyAppearance(ped, appearance)
        return
    end

    if changed == 'headBlend' then
        local hb = appearance.headBlend
        if hb then
            SetPedHeadBlendData(
                ped,
                hb.shapeFirst or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
                hb.skinFirst or 0, hb.skinSecond or 0, hb.skinThird or 0,
                hb.shapeMix or 0.5, hb.skinMix or 0.5, hb.thirdMix or 0.0,
                false
            )
        end
        return
    end

    local featureIndex = changed:match('^faceFeature:(%d+)$')
    if featureIndex then
        local i = tonumber(featureIndex)
        SetPedFaceFeature(ped, i, (appearance.faceFeatures and appearance.faceFeatures[i + 1]) or 0.0)
        return
    end

    local overlayId = changed:match('^overlay:(%-?%d+)$')
    if overlayId then
        local id = tonumber(overlayId)
        for _, overlay in ipairs(Config.HeadOverlays) do
            if overlay.id == id then
                local data = appearance.headOverlays and appearance.headOverlays[tostring(id)]
                if data then
                    SetPedHeadOverlay(ped, id, data.index or -1, data.opacity or 1.0)
                    if overlay.hasColor then
                        SetPedHeadOverlayColor(ped, id, data.colorType or 1, data.colorIndex or 0, data.secondColorIndex or 0)
                    end
                end
                break
            end
        end
        return
    end

    if changed == 'hair' then
        if appearance.hair then
            SetPedComponentVariation(ped, 2, appearance.hair.style or 0, 0, 0)
            SetPedHairColor(ped, appearance.hair.color or 0, appearance.hair.highlight or 0)
        end
        return
    end

    if changed == 'eyeColor' then
        SetPedEyeColor(ped, appearance.eyeColor or 0)
        return
    end

    local componentSlot = changed:match('^component:(%d+)$')
    if componentSlot then
        local slot = tonumber(componentSlot)
        local data = appearance.components and appearance.components[tostring(slot)]
        if data then
            SetPedComponentVariation(ped, slot, data.drawable or 0, data.texture or 0, 0)
        end
        return
    end

    local propSlot = changed:match('^prop:(%d+)$')
    if propSlot then
        local slot = tonumber(propSlot)
        local data = appearance.props and appearance.props[tostring(slot)]
        if data then
            if not data.drawable or data.drawable < 0 then
                ClearPedProp(ped, slot)
            else
                SetPedPropIndex(ped, slot, data.drawable, data.texture or 0, true)
            end
        end
        return
    end

    -- Ismeretlen hint - biztonság kedvéért essünk vissza a teljes alkalmazásra
    NBChar.ApplyAppearance(ped, appearance)
end
function NBChar.ApplyAppearance(ped, appearance)
    if not appearance then return end

    -- Fej keverés (két/három "szülő" arc- és bőrtípus keverve)
    local hb = appearance.headBlend
    if hb then
        SetPedHeadBlendData(
            ped,
            hb.shapeFirst or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
            hb.skinFirst or 0, hb.skinSecond or 0, hb.skinThird or 0,
            hb.shapeMix or 0.5, hb.skinMix or 0.5, hb.thirdMix or 0.0,
            false
        )
    end

    -- Arc jellemzők (orr, arccsont, áll stb. finomhangolása)
    if appearance.faceFeatures then
        for i = 1, Config.FaceFeatureCount do
            local value = appearance.faceFeatures[i] or 0.0
            SetPedFaceFeature(ped, i - 1, value)
        end
    end

    -- Head overlay-ok (smink, szakáll, hegek stb.)
    if appearance.headOverlays then
        for _, overlay in ipairs(Config.HeadOverlays) do
            local data = appearance.headOverlays[tostring(overlay.id)]
            if data then
                SetPedHeadOverlay(ped, overlay.id, data.index or -1, data.opacity or 1.0)
                if overlay.hasColor then
                    SetPedHeadOverlayColor(ped, overlay.id, data.colorType or 1, data.colorIndex or 0, data.secondColorIndex or 0)
                end
            end
        end
    end

    -- Szemszín
    if appearance.eyeColor then
        SetPedEyeColor(ped, appearance.eyeColor)
    end

    -- Haj (forma + szín)
    if appearance.hair then
        SetPedComponentVariation(ped, 2, appearance.hair.style or 0, 0, 0)
        SetPedHairColor(ped, appearance.hair.color or 0, appearance.hair.highlight or 0)
    end

    -- Ruházat komponensek
    if appearance.components then
        for _, slot in ipairs(Config.ClothingComponents) do
            local data = appearance.components[tostring(slot)]
            if data then
                SetPedComponentVariation(ped, slot, data.drawable or 0, data.texture or 0, 0)
            end
        end
    end

    -- Kiegészítők (kalap, szemüveg stb.) - -1 drawable = nincs felvéve
    if appearance.props then
        for _, slot in ipairs(Config.PropSlots) do
            local data = appearance.props[tostring(slot)]
            if data then
                if not data.drawable or data.drawable < 0 then
                    ClearPedProp(ped, slot)
                else
                    SetPedPropIndex(ped, slot, data.drawable, data.texture or 0, true)
                end
            end
        end
    end
end
