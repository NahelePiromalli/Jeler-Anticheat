local isAuthenticated = false
local PlayerSuspicion = {} 
local PlayerStats = {}     
local API_URL = "https://tu-api.com/verify"
local PlayerPositions = {} 
local GodmodeStrikes = {}  
local PlayerTokens = {}    
local EntityRates = {}     

-- CACHÉ
local BlacklistedVehHashes = {}
local BlacklistedWepHashes = {}
local WhitelistedVehHashes = {}

-- Hashes de Armas (Group)
local WeaponGroups = {
    [GetHashKey("WEAPON_SNIPERRIFLE")] = 'sniper', [GetHashKey("WEAPON_HEAVYSNIPER")] = 'sniper',
    [GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = 'sniper', [GetHashKey("WEAPON_MARKSMANRIFLE")] = 'sniper',
    [GetHashKey("WEAPON_PUMPSHOTGUN")] = 'shotgun', [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = 'shotgun',
    [GetHashKey("WEAPON_MICROSMG")] = 'smg', [GetHashKey("WEAPON_SMG")] = 'smg'
}

-- =============================================================================
-- INICIALIZACIÓN
-- =============================================================================
Citizen.CreateThread(function()
    for _, v in pairs(Config.BlacklistedVehicles) do BlacklistedVehHashes[GetHashKey(v)] = true end
    for _, w in pairs(Config.BlacklistedWeapons) do BlacklistedWepHashes[GetHashKey(w)] = true end
    if Config.WhitelistedVehicles then
        for _, v in pairs(Config.WhitelistedVehicles) do WhitelistedVehHashes[GetHashKey(v)] = true end
    end
    print("^2[Jeler AC] ^7Sistema Iniciado. Whitelist Vehiculos: "..(Config.WhitelistedVehicles and #Config.WhitelistedVehicles or 0))
end)

local function GenerateToken()
    local charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local token = ""
    for i = 1, 32 do local rand = math.random(#charset); token = token .. string.sub(charset, rand, rand) end
    return token
end

local function ValidateToken(src, receivedToken)
    if not PlayerTokens[src] or PlayerTokens[src] ~= receivedToken then
        DropPlayer(src, "🛡️ Jeler AC: Security Token Mismatch (Injector Detected)")
        return false
    end
    return true
end

RegisterNetEvent('jeler:requestToken')
AddEventHandler('jeler:requestToken', function()
    local src = source
    if not PlayerTokens[src] then
        local token = GenerateToken()
        PlayerTokens[src] = token
        TriggerClientEvent('jeler:setToken', src, token)
    end
end)

-- Honeypots
local HoneyPotEvents = {
    "esx:giveInventoryItem", "admin:reviveAll", "bank:transfer",
    "vrp:addMoney", "qb-core:server:Player:SetPlayerData", "anticheat:bypass"
}
for _, eventName in pairs(HoneyPotEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function()
        DropPlayer(source, "🛡️ Jeler AC: HoneyPot Triggered ("..eventName..")")
    end)
end

-- =============================================================================
-- MÓDULO 1: ANTI-SPAM
-- =============================================================================
AddEventHandler('entityCreating', function(entity)
    if not isAuthenticated then return end
    local owner = NetworkGetEntityOwner(entity)
    if not owner then return end
    
    if not EntityRates[owner] then EntityRates[owner] = 0 end
    EntityRates[owner] = EntityRates[owner] + 1
    
    if EntityRates[owner] > Config.MaxEntitiesPerSecond then
        CancelEvent()
        if EntityRates[owner] > (Config.MaxEntitiesPerSecond + 10) then 
            DropPlayer(owner, "🛡️ Jeler AC: Entity Spam Detected")
        end
        return
    end

    local model = GetEntityModel(entity)
    for _, blockedModel in ipairs(Config.BlacklistedEntities) do
        if model == GetHashKey(blockedModel) then CancelEvent(); break end
    end
end)

Citizen.CreateThread(function() while true do Citizen.Wait(1000); EntityRates = {} end end)

AddEventHandler('explosionEvent', function(sender, ev)
    if not sender then CancelEvent(); return end
    for _, type in ipairs(Config.BlacklistedExplosions) do
        if ev.explosionType == type then CancelEvent(); DropPlayer(sender, "🛡️ Jeler AC: Illegal Explosion"); return end
    end
end)

-- =============================================================================
-- MÓDULO 2: GODMODE / MAGIC BULLET / DAÑO EXTREMO
-- =============================================================================
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not isAuthenticated then return end
    
    local victimId = data.hitGlobalId
    local victimPed = GetPlayerPed(victimId)
    local shooter = GetPlayerPed(sender)
    
    if not DoesEntityExist(victimPed) or not IsPedAPlayer(victimPed) then return end
    if data.weaponDamage <= 0 then return end

    -- [A] VALIDACIÓN DE DAÑO MÁXIMO (Server-Side Limit)
    local damageLimit = 250
    local weaponHash = GetSelectedPedWeapon(shooter)
    local wClass = WeaponGroups[weaponHash] or 'default'
    if wClass == 'sniper' then damageLimit = 400 end
    
    if data.weaponDamage > damageLimit then
        AddSuspicion(sender, 100, "Extreme Damage: " .. math.floor(data.weaponDamage) .. "HP")
        return 
    end

    -- [B] GODMODE CHECK
    local healthBefore = GetEntityHealth(victimPed)
    local armorBefore = GetPedArmour(victimPed)

    SetTimeout(150, function()
        if not DoesEntityExist(victimPed) then return end
        local healthAfter = GetEntityHealth(victimPed)
        local armorAfter = GetPedArmour(victimPed)

        if healthBefore == healthAfter and armorBefore == armorAfter then
            if IsEntityDead(victimPed) then return end
            if IsPlayerAceAllowed(victimId, "jeler.bypass") then return end

            if not GodmodeStrikes[victimId] then GodmodeStrikes[victimId] = 0 end
            GodmodeStrikes[victimId] = GodmodeStrikes[victimId] + 1
            
            if GodmodeStrikes[victimId] >= Config.GodmodeStrikes then
                DropPlayer(victimId, "🛡️ Jeler AC: Invencibilidad Detectada (Godmode)")
            end
        else
            if GodmodeStrikes[victimId] and GodmodeStrikes[victimId] > 0 then
                GodmodeStrikes[victimId] = GodmodeStrikes[victimId] - 1
            end
        end
    end)
    
    -- [C] AIM ANALYSIS
    if IsPlayerAceAllowed(sender, "jeler.bypass") then return end

    local wConfig = Config.WeaponClasses[wClass]
    local ping = GetPlayerPing(sender)
    local tolerance = wConfig.tolerance
    local hitRadius = Config.MaxHitboxRadius
    
    -- Tolerancia Dinámica (Legit Play)
    if IsPedInCover(shooter, 0) then tolerance = 50.0; hitRadius = hitRadius + 0.5 end
    if GetEntitySpeed(shooter) > 2.5 then tolerance = tolerance * 2.0 end
    if IsPedInAnyVehicle(shooter, false) then tolerance = tolerance * 2.5 end
    if ping > Config.PingAssist then tolerance = tolerance * 1.5; hitRadius = hitRadius + 0.15 end

    local headPos = MathUtils.GetHeadCoords(shooter)
    local hitPos = GetEntityCoords(victimPed)
    if data.hitComponent == 31086 then 
        local s, h = pcall(GetPedBoneCoords, victimPed, 31086, 0.0, 0.0, 0.0)
        if s then hitPos = h end
    end

    if #(hitPos - headPos) < 3.0 then return end 

    local bulletVec = MathUtils.NormalizeVector(hitPos - headPos)
    local camDir = MathUtils.RotationToDirection(GetEntityRotation(shooter, 2))
    
    -- CHECK: MAGIC BULLET
    local missDist = MathUtils.DistanceFromLineToPoint(headPos, camDir, hitPos)
    if missDist > hitRadius then
        AddSuspicion(sender, Config.MagicBulletSeverity, "Magic Bullet (Miss: "..string.format("%.2fm", missDist)..")")
        return 
    end

    -- CHECK: SILENT AIM
    local angle = MathUtils.CalculateAngle(bulletVec, camDir)
    if angle > tolerance then
        local excess = angle - tolerance
        AddSuspicion(sender, wConfig.severity + (excess * 2), "Silent Aim (Dev: "..string.format("%.1f", angle).."°)")
    else
        RewardLegitShot(sender)
        
        -- HEURÍSTICA
        if not PlayerStats[sender] then PlayerStats[sender] = { shots = 0, angles = {}, bones = {} } end
        local st = PlayerStats[sender]
        st.shots = st.shots + 1
        table.insert(st.angles, angle)
        table.insert(st.bones, data.hitComponent)
        
        if st.shots >= Config.AnalysisWindow then
            AnalyzeHeuristics(sender, st)
            PlayerStats[sender] = { shots = 0, angles = {}, bones = {} } 
        end
    end
end)

-- =============================================================================
-- MÓDULO 3: LOOP DE SEGURIDAD
-- =============================================================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.NoclipCheckInterval)
        if isAuthenticated then
            for _, playerId in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(playerId)
                
                if DoesEntityExist(ped) and not IsPlayerAceAllowed(playerId, "jeler.bypass") then
                    
                    -- [A] VEHÍCULOS (Blacklist y Whitelist)
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    local isInVehicle = (vehicle ~= 0)
                    local model = 0
                    
                    if isInVehicle then
                        model = GetEntityModel(vehicle)
                        if Config.DebugMode and math.random(1,100) < 5 then print("^4[INFO] ID "..playerId.." CarHash: "..model) end
                        
                        if BlacklistedVehHashes[model] then
                            if Config.BlacklistAction == "ban" then DropPlayer(playerId, "🛡️ Jeler AC: Vehículo Prohibido")
                            elseif Config.BlacklistAction == "delete" then DeleteEntity(vehicle) end
                        end
                    end

                    -- [B] ARMAS
                    local weaponHash = GetSelectedPedWeapon(ped)
                    if weaponHash ~= -1569615261 and BlacklistedWepHashes[weaponHash] then
                        if Config.BlacklistAction == "ban" then DropPlayer(playerId, "🛡️ Jeler AC: Arma Prohibida")
                        elseif Config.BlacklistAction == "delete" then RemoveWeaponFromPed(ped, weaponHash) end
                    end

                    -- [C] MOVIMIENTO
                    local pos = GetEntityCoords(ped)
                    if PlayerPositions[playerId] then
                        local distance = #(pos - PlayerPositions[playerId])
                        local speed = distance / (Config.NoclipCheckInterval / 1000)
                        local isFalling = IsPedFalling(ped) or IsPedRagdoll(ped) or IsPedInParachuteFreeFall(ped)
                        
                        if not isFalling then
                            if not isInVehicle then
                                if speed > Config.MaxRunSpeed then
                                    AddSuspicion(playerId, 20, "Speedhack/Noclip (On Foot: "..math.floor(speed).."m/s)")
                                end
                                local heightDiff = pos.z - PlayerPositions[playerId].z
                                if heightDiff > Config.MaxFlyHeight then
                                    AddSuspicion(playerId, 50, "Flying/Noclip (Altura: +"..math.floor(heightDiff).."m)")
                                end
                            else
                                -- Speedhack Vehículo (Respetando Whitelist)
                                if not WhitelistedVehHashes[model] then
                                    if speed > Config.MaxVehicleSpeed then
                                        AddSuspicion(playerId, 15, "Vehicle Speedhack (Vel: "..math.floor(speed).."m/s)")
                                    end
                                end
                            end
                        end
                    end
                    PlayerPositions[playerId] = pos
                else
                    PlayerPositions[playerId] = nil
                end
            end
        end
    end
end)

-- SISTEMA BASE
AddEventHandler('onResourceStart', function(res)
    if GetCurrentResourceName() ~= res then return end
    if Config.LicenseKey == "TEST-DEV-KEY" then isAuthenticated = true else isAuthenticated = true end
end)

function AddSuspicion(source, points, reason)
    if not PlayerSuspicion[source] then PlayerSuspicion[source] = 0.0 end
    PlayerSuspicion[source] = PlayerSuspicion[source] + points
    if Config.DebugMode then
        print(string.format("^3[ANALYSIS] ^7ID:%s | +%.1f pts | Total: %.1f/%d | Razón: %s", source, points, PlayerSuspicion[source], Config.BanThreshold, reason))
    end
    if PlayerSuspicion[source] >= Config.BanThreshold then
        DropPlayer(source, "🛡️ Jeler AC: Detección Confirmada ("..reason..")")
        PlayerSuspicion[source] = 0 
    end
end

function RewardLegitShot(source)
    if PlayerSuspicion[source] and PlayerSuspicion[source] > 0 then
        PlayerSuspicion[source] = PlayerSuspicion[source] - Config.LegitReward
        if PlayerSuspicion[source] < 0 then PlayerSuspicion[source] = 0 end
    end
end

function AnalyzeHeuristics(source, stats)
    local uniqueBones = {}
    for _, b in pairs(stats.bones) do uniqueBones[b] = true end
    local count = 0
    for _ in pairs(uniqueBones) do count = count + 1 end
    if count < Config.MinBoneVariety then AddSuspicion(source, 35, "Bone Locking") end
    local variance = MathUtils.StandardDeviation(stats.angles)
    local avgAngle = MathUtils.Average(stats.angles)
    if avgAngle < 8.0 and variance < Config.MinAngularVariance then AddSuspicion(source, 50, "Robotic Aim") end
end

RegisterNetEvent('jeler:flag')
AddEventHandler('jeler:flag', function(token, reason)
    local src = source
    if not ValidateToken(src, token) then return end
    AddSuspicion(src, 100, "Client Flag: " .. reason)
end)

RegisterNetEvent('jeler:heartbeat')
AddEventHandler('jeler:heartbeat', function(token)
    local src = source
    if not ValidateToken(src, token) then return end
end)