local isAuthenticated = false
local PlayerSuspicion = {} 
local PlayerStats = {}     
local API_URL = "https://tu-api.com/verify"
local PlayerPositions = {} 
local GodmodeStrikes = {}  
local EntityRates = {}     
local LastHeartbeat = {} 

-- NUEVO SISTEMA DE SEGURIDAD
local PlayerSecurity = {} -- Estructura: { [src] = { token = "xyz", sequence = 0 } }

-- CACHÉ
local BlacklistedVehHashes = {}
local BlacklistedWepHashes = {}
local WhitelistedVehHashes = {}

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
    Citizen.Wait(1000)
    local oneSync = GetConvar("onesync", "off")
    if oneSync == "off" then
        print("^1[Jeler AC] ^7ERROR: OneSync requerido.")
        return 
    end

    for _, v in pairs(Config.BlacklistedVehicles) do BlacklistedVehHashes[GetHashKey(v)] = true end
    for _, w in pairs(Config.BlacklistedWeapons) do BlacklistedWepHashes[GetHashKey(w)] = true end
    if Config.WhitelistedVehicles then
        for _, v in pairs(Config.WhitelistedVehicles) do WhitelistedVehHashes[GetHashKey(v)] = true end
    end
    print("^2[Jeler AC] ^7Sistema Iniciado (Stateful Tokens Activos).")
end)

-- =============================================================================
-- SISTEMA DE TOKENS DINÁMICOS Y STATEFUL
-- =============================================================================

-- Generador de Tokens con Entropía (ID + Time + Nonce)
local function GenerateSecureToken(src, nonce)
    local time = os.time()
    local salt = math.random(100000, 999999)
    -- Simulamos un hash complejo combinando factores variables
    local rawString = string.format("%s:%s:%s:%s", src, time, nonce, salt)
    
    -- "Hash" manual simple (XOR mix) para evitar texto plano
    local hash = ""
    for i = 1, #rawString do
        local byte = string.byte(rawString, i)
        hash = hash .. string.format("%02x", byte ~ 0xAB) -- XOR con 0xAB
    end
    
    return hash
end

-- Validador Stateful (Verifica Token y Orden de Eventos)
local function ValidateToken(src, receivedToken, receivedSeq)
    local data = PlayerSecurity[src]
    
    -- 1. Existe sesión?
    if not data then 
        DropPlayer(src, "🛡️ Jeler AC: No Session Data")
        return false 
    end

    -- 2. Token coincide?
    if data.token ~= receivedToken then
        DropPlayer(src, "🛡️ Jeler AC: Invalid Security Token")
        return false
    end

    -- 3. Validación de Secuencia (Solo si se provee seq, ej: Heartbeat)
    -- Esto evita ataques de repetición (Replay Attacks)
    if receivedSeq then
        if receivedSeq <= data.sequence then
            -- Paquete antiguo o duplicado (posible lag o ataque)
            -- No baneamos directo por UDP, pero ignoramos el paquete
            return false
        end
        data.sequence = receivedSeq -- Actualizamos la secuencia esperada
    end

    return true
end

-- Hilo de Rotación de Tokens (Cada X minutos)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.TokenRotationInterval * 1000)
        
        print("^4[Jeler AC] ^7Rotando tokens de seguridad...")
        local nonce = math.random(1, 1000)
        
        for _, playerId in ipairs(GetPlayers()) do
            if PlayerSecurity[playerId] then
                local newToken = GenerateSecureToken(playerId, nonce)
                PlayerSecurity[playerId].token = newToken
                -- Reseteamos secuencia o la mantenemos? Mejor mantener para continuidad,
                -- o resetear si el cliente también resetea. 
                -- Para seguridad, vamos a sincronizar el reset.
                PlayerSecurity[playerId].sequence = 0 
                
                TriggerClientEvent('jeler:updateToken', playerId, newToken)
            end
        end
    end
end)

-- Solicitud Inicial
RegisterNetEvent('jeler:requestToken')
AddEventHandler('jeler:requestToken', function()
    local src = source
    if not PlayerSecurity[src] then
        local nonce = 0
        local token = GenerateSecureToken(src, nonce)
        PlayerSecurity[src] = {
            token = token,
            sequence = 0
        }
        TriggerClientEvent('jeler:setToken', src, token)
        LastHeartbeat[src] = os.time()
    end
end)

-- =============================================================================
-- GESTIÓN DE BANEO
-- =============================================================================
function AddSuspicion(source, points, reason)
    if not PlayerSuspicion[source] then PlayerSuspicion[source] = 0.0 end
    PlayerSuspicion[source] = PlayerSuspicion[source] + points
    
    if Config.DebugMode then
        print(string.format("^3[ANALYSIS] ^7ID:%s | +%.1f pts | Total: %.1f/%d | Razón: %s", 
            source, points, PlayerSuspicion[source], Config.BanThreshold, reason))
    end

    if PlayerSuspicion[source] >= Config.BanThreshold then
        print("^1[AUTOBAN] ^7Baneando a ID "..source)
        DropPlayer(source, "🛡️ Jeler AC: Detección Confirmada ("..reason..")")
        PlayerSuspicion[source] = 0 
    end
end

-- =============================================================================
-- MÓDULOS DE PROTECCIÓN
-- =============================================================================

-- Honeypots
local HoneyPotEvents = {
    "esx:giveInventoryItem", "admin:reviveAll", "bank:transfer",
    "vrp:addMoney", "qb-core:server:Player:SetPlayerData", "anticheat:bypass"
}
for _, eventName in pairs(HoneyPotEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function()
        DropPlayer(source, "🛡️ Jeler AC: HoneyPot Triggered")
    end)
end

-- Anti-Spam
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

-- Anti-Explosiones
AddEventHandler('explosionEvent', function(sender, ev)
    if not sender then CancelEvent(); return end
    for _, type in ipairs(Config.BlacklistedExplosions) do
        if ev.explosionType == type then CancelEvent(); DropPlayer(sender, "🛡️ Jeler AC: Illegal Explosion"); return end
    end
end)

-- Anti-Command Injection
AddEventHandler('executeCommand', function(commandSource, command)
    if not commandSource or commandSource == 0 then return end
    local cmd = string.lower(command)
    for _, blockedCmd in ipairs(Config.BlacklistedCommands) do
        if string.find(cmd, blockedCmd) then
            if IsPlayerAceAllowed(commandSource, "jeler.bypass") then return end
            CancelEvent()
            AddSuspicion(commandSource, 100, "Illegal Command Injection: /"..cmd)
            return
        end
    end
end)

-- =============================================================================
-- COMBATE Y HEURÍSTICA
-- =============================================================================
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not isAuthenticated then return end
    local victimId = data.hitGlobalId
    local victimPed = GetPlayerPed(victimId)
    local shooter = GetPlayerPed(sender)
    
    if not DoesEntityExist(victimPed) or not IsPedAPlayer(victimPed) then return end
    if data.weaponDamage <= 0 then return end

    -- Max Damage Limit
    local damageLimit = 250
    local weaponHash = GetSelectedPedWeapon(shooter)
    local wClass = WeaponGroups[weaponHash] or 'default'
    if wClass == 'sniper' then damageLimit = 400 end
    
    if data.weaponDamage > damageLimit then
        AddSuspicion(sender, 100, "Extreme Damage: " .. math.floor(data.weaponDamage) .. "HP")
        return 
    end

    -- Godmode Check
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
                AddSuspicion(victimId, 100, "Godmode (Health Lock)") 
            end
        else
            if GodmodeStrikes[victimId] and GodmodeStrikes[victimId] > 0 then
                GodmodeStrikes[victimId] = GodmodeStrikes[victimId] - 1
            end
        end
    end)
    
    -- Aim Analysis
    if IsPlayerAceAllowed(sender, "jeler.bypass") then return end

    local wConfig = Config.WeaponClasses[wClass]
    local ping = GetPlayerPing(sender)
    local tolerance = wConfig.tolerance
    local hitRadius = Config.MaxHitboxRadius
    
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
    
    local missDist = MathUtils.DistanceFromLineToPoint(headPos, camDir, hitPos)
    if missDist > hitRadius then
        AddSuspicion(sender, Config.MagicBulletSeverity, "Magic Bullet (Miss: "..string.format("%.2fm", missDist)..")")
        return 
    end

    local angle = MathUtils.CalculateAngle(bulletVec, camDir)
    if angle > tolerance then
        local excess = angle - tolerance
        AddSuspicion(sender, wConfig.severity + (excess * 2), "Silent Aim (Dev: "..string.format("%.1f", angle).."°)")
    else
        RewardLegitShot(sender)
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

-- LOOP DE SEGURIDAD
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.NoclipCheckInterval)
        if isAuthenticated then
            for _, playerId in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(playerId)
                
                if DoesEntityExist(ped) and not IsPlayerAceAllowed(playerId, "jeler.bypass") then
                    -- Vehículos
                    local vehicle = GetVehiclePedIsIn(ped, false)
                    local isInVehicle = (vehicle ~= 0)
                    local model = 0
                    if isInVehicle then
                        model = GetEntityModel(vehicle)
                        if BlacklistedVehHashes[model] then
                            if Config.BlacklistAction == "ban" then AddSuspicion(playerId, 100, "Vehículo Prohibido")
                            elseif Config.BlacklistAction == "delete" then DeleteEntity(vehicle) end
                        end
                    end
                    -- Armas
                    local weaponHash = GetSelectedPedWeapon(ped)
                    if weaponHash ~= -1569615261 and BlacklistedWepHashes[weaponHash] then
                        if Config.BlacklistAction == "ban" then AddSuspicion(playerId, 100, "Arma Prohibida")
                        elseif Config.BlacklistAction == "delete" then RemoveWeaponFromPed(ped, weaponHash) end
                    end
                    -- Movimiento
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

-- Watchdog
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        local now = os.time()
        for _, playerId in ipairs(GetPlayers()) do
            if LastHeartbeat[playerId] then
                local timeSinceLast = now - LastHeartbeat[playerId]
                if timeSinceLast > Config.HeartbeatTimeout then
                    print("^1[WATCHDOG] ^7ID "..playerId.." dejó de responder.")
                    DropPlayer(playerId, "🛡️ Jeler AC: Security Resource Stopped / Desync")
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

AddEventHandler('playerDropped', function() 
    LastHeartbeat[source] = nil 
    PlayerSecurity[source] = nil
end)

-- EVENTOS PROTEGIDOS CON TOKEN Y SECUENCIA
RegisterNetEvent('jeler:flag')
AddEventHandler('jeler:flag', function(token, reason)
    local src = source
    -- Las flags no usan secuencia estricta porque son esporádicas, pero validamos el token
    if not ValidateToken(src, token) then return end
    AddSuspicion(src, 100, "Client Flag: " .. reason)
end)

RegisterNetEvent('jeler:heartbeat')
AddEventHandler('jeler:heartbeat', function(token, seq)
    local src = source
    -- El heartbeat SI usa secuencia para asegurar orden
    if not ValidateToken(src, token, seq) then return end
    LastHeartbeat[src] = os.time()
end)