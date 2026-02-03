local isAuthenticated = false
local PlayerSuspicion = {} 
local PlayerStats = {}     
local PlayerPositions = {} 
local GodmodeStrikes = {}  
local EntityRates = {}     
local LastHeartbeat = {} 
local SpamGuard = {} 

local PlayerRotations = {} 
local PlayerSecurity = {} 

local BlacklistedVehHashes = {}
local BlacklistedWepHashes = {}
local WhitelistedVehHashes = {}

local WeaponGroups = {
    [GetHashKey("WEAPON_SNIPERRIFLE")] = 'sniper', [GetHashKey("WEAPON_HEAVYSNIPER")] = 'sniper',
    [GetHashKey("WEAPON_HEAVYSNIPER_MK2")] = 'sniper', [GetHashKey("WEAPON_MARKSMANRIFLE")] = 'sniper',
    [GetHashKey("WEAPON_PUMPSHOTGUN")] = 'shotgun', [GetHashKey("WEAPON_SAWNOFFSHOTGUN")] = 'shotgun',
    [GetHashKey("WEAPON_MICROSMG")] = 'smg', [GetHashKey("WEAPON_SMG")] = 'smg'
}

-- INICIALIZACIÓN
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    local oneSync = GetConvar("onesync", "off")
    if oneSync == "off" then print("^1[Jeler AC] ^7ERROR: OneSync requerido.") return end

    for _, v in pairs(Config.BlacklistedVehicles) do BlacklistedVehHashes[GetHashKey(v)] = true end
    for _, w in pairs(Config.BlacklistedWeapons) do BlacklistedWepHashes[GetHashKey(w)] = true end
    if Config.WhitelistedVehicles then
        for _, v in pairs(Config.WhitelistedVehicles) do WhitelistedVehHashes[GetHashKey(v)] = true end
    end
    print("^2[Jeler AC] ^7v14.0 PRODUCCIÓN (BANEO ACTIVO + HWID).")
end)

-- =====================================================
-- SISTEMA DE BANEOS (PERSISTENCIA JSON + HWID)
-- =====================================================
local BanList = {}

-- Cargar baneos al iniciar
Citizen.CreateThread(function()
    local loadFile = LoadResourceFile(GetCurrentResourceName(), "bans.json")
    if loadFile then
        BanList = json.decode(loadFile)
    else
        SaveResourceFile(GetCurrentResourceName(), "bans.json", "[]", -1)
    end
    print("^2[Jeler AC] ^7Ban List Cargada: " .. #BanList .. " usuarios baneados.")
end)

local function BanPlayer(src, reason)
    local ids = GetPlayerIdentifiers(src)
    local tokens = {}
    local numTokens = GetNumPlayerTokens(src)
    for i = 0, numTokens - 1 do
        table.insert(tokens, GetPlayerToken(src, i))
    end

    local banData = {
        ids = ids,
        tokens = tokens, 
        reason = reason,
        date = os.date("%d/%m/%Y %H:%M"),
        name = GetPlayerName(src)
    }
    
    table.insert(BanList, banData)
    SaveResourceFile(GetCurrentResourceName(), "bans.json", json.encode(BanList, { indent = true }), -1)
    
    print("^1[BAN] ^7HWID BANEADO: " .. GetPlayerName(src))
    -- ESTA LÍNEA ES LA QUE EXPULSA AL JUGADOR
    DropPlayer(src, "⛔ Jeler AC: HAS SIDO BANEADO PERMANENTEMENTE (" .. reason .. ")")
end

-- Bloquear entrada (Check Completo)
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local src = source
    local ids = GetPlayerIdentifiers(src)
    local myTokens = {}
    local numTokens = GetNumPlayerTokens(src)
    for i = 0, numTokens - 1 do
        table.insert(myTokens, GetPlayerToken(src, i))
    end
    
    deferrals.defer()
    Wait(50) 
    
    for _, ban in ipairs(BanList) do
        local banned = false
        -- Check ID (Steam, Discord, Licencia)
        for _, bannedId in ipairs(ban.ids) do
            for _, myId in ipairs(ids) do
                if bannedId == myId then banned = true break end
            end
            if banned then break end
        end
        
        -- Check HWID (Token PC)
        if not banned and ban.tokens then
            for _, bannedToken in ipairs(ban.tokens) do
                for _, myToken in ipairs(myTokens) do
                    if bannedToken == myToken then
                        banned = true
                        print("^3[Jeler AC] ^7Evasión detectada (HWID): " .. name)
                        break
                    end
                end
                if banned then break end
            end
        end

        if banned then
            deferrals.done("⛔ Jeler AC: BANEADO POR HARDWARE. Razón: " .. ban.reason .. " (Fecha: " .. ban.date .. ")")
            return
        end
    end
    
    deferrals.done()
end)

-- =====================================================
-- COMANDO UNBAN INTELIGENTE (DISCORD SUPPORT)
-- =====================================================
RegisterCommand("jeler_unban", function(source, args, rawCommand)
    local src = source
    if src ~= 0 then
        if not IsPlayerAceAllowed(src, "jeler.admin") then 
            print("^1[ACCESO DENEGADO] ^7No tienes permiso.")
            return 
        end
    end

    local target = args[1]
    if not target then 
        print("^3[USO] ^7/jeler_unban [steam:xx / license:xx / discord:xx]") 
        return 
    end

    if string.match(target, "^%d+$") then
        target = "discord:" .. target
        print("^3[INFO] ^7Detectado ID numérico, buscando como: " .. target)
    end

    local newBanList = {}
    local found = false

    for _, ban in ipairs(BanList) do
        local match = false
        for _, id in ipairs(ban.ids) do
            if id == target then match = true break end
        end
        
        if not match then
            table.insert(newBanList, ban)
        else
            found = true
            print("^2[Jeler AC] ^7Baneo ELIMINADO para: " .. (ban.name or "Desconocido"))
        end
    end

    if found then
        BanList = newBanList
        SaveResourceFile(GetCurrentResourceName(), "bans.json", json.encode(BanList, { indent = true }), -1)
        print("^2[ÉXITO] ^7Jugador desbaneado correctamente.")
    else
        print("^1[ERROR] ^7No se encontró ningún baneo con ese ID ("..target..").")
    end
end, true)

-- =====================================================
-- SISTEMA DE ENCRIPTACIÓN & TOKENS
-- =====================================================
local function XOREncrypt(str, key)
    local res = {}
    for i = 1, #str do
        local keyByte = string.byte(key, (i - 1) % #key + 1)
        table.insert(res, string.char(string.byte(str, i) ~ keyByte))
    end
    return table.concat(res)
end

local Charset = {}
for i = 48,  57 do table.insert(Charset, string.char(i)) end
for i = 65,  90 do table.insert(Charset, string.char(i)) end
for i = 97, 122 do table.insert(Charset, string.char(i)) end

local function GenerateSecureToken(src, nonce)
    local length = 64
    local token = ""
    math.randomseed(os.time() + (os.clock() * 100000) + src + (nonce or 0))
    for i = 1, length do
        token = token .. Charset[math.random(1, #Charset)]
    end
    return token
end

local function ValidateToken(src, receivedToken, receivedSeq)
    local data = PlayerSecurity[src]
    if not data then return false end
    if data.token ~= receivedToken then return false end
    if receivedSeq then
        if receivedSeq <= data.sequence then return false end
        data.sequence = receivedSeq
    end
    return true
end

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.TokenRotationInterval * 1000)
        local nonce = math.random(1, 10000)
        for _, playerId in ipairs(GetPlayers()) do
            if PlayerSecurity[playerId] then
                local newToken = GenerateSecureToken(playerId, nonce)
                PlayerSecurity[playerId].token = newToken
                PlayerSecurity[playerId].sequence = 0 
                TriggerClientEvent('jeler:updateToken', playerId, newToken)
            end
        end
    end
end)

RegisterNetEvent('jeler:requestToken')
AddEventHandler('jeler:requestToken', function()
    local src = source
    if not PlayerSecurity[src] then
        local nonce = 0
        local token = GenerateSecureToken(src, nonce)
        PlayerSecurity[src] = { token = token, sequence = 0 }
        TriggerClientEvent('jeler:setToken', src, token)
        LastHeartbeat[src] = os.time()
    end
end)

function AddSuspicion(source, points, reason)
    if not PlayerSuspicion[source] then PlayerSuspicion[source] = 0.0 end
    PlayerSuspicion[source] = PlayerSuspicion[source] + points
    
    -- Si el DebugMode estuviera en TRUE, solo imprimiría esto.
    -- Como ahora está en FALSE, pasará directo a la lógica de abajo sin avisar.
    if Config.DebugMode then
        print(string.format("^3[ANALYSIS] ^7ID:%s | +%.1f pts | Total: %.1f/%d | Razón: %s", source, points, PlayerSuspicion[source], Config.BanThreshold, reason))
    end

    -- LOGICA DE BANEO: Si supera el límite (100), BANEA
    if PlayerSuspicion[source] >= Config.BanThreshold then
        BanPlayer(source, reason) 
        PlayerSuspicion[source] = 0 
    end
end

-- PROTECCIONES DE EVENTOS
local HoneyPotEvents = { "esx:giveInventoryItem", "admin:reviveAll", "bank:transfer", "vrp:addMoney", "anticheat:bypass" }
for _, eventName in pairs(HoneyPotEvents) do
    RegisterNetEvent(eventName)
    AddEventHandler(eventName, function() 
        AddSuspicion(source, 100, "HoneyPot Triggered: "..eventName)
    end)
end

RegisterNetEvent('jeler:flag')
AddEventHandler('jeler:flag', function(token, encryptedReason)
    local src = source
    if not ValidateToken(src, token) then return end
    local reason = XOREncrypt(encryptedReason, token)
    AddSuspicion(src, 100, "Client Flag: " .. reason)
end)

-- ANTI-CRASH
local SpamCheck = {}
local MaxVehiclesPerSec = 5  
local MaxPedsPerSec = 5      
local MaxObjectsPerSec = 10  

AddEventHandler('entityCreating', function(entity)
    if not isAuthenticated then return end
    local src = NetworkGetEntityOwner(entity)
    if not src then return end
    
    local popType = GetEntityPopulationType(entity)
    if popType > 0 and popType < 6 then return end 

    if not SpamCheck[src] then SpamCheck[src] = { veh = 0, ped = 0, obj = 0, time = os.time() } end
    if os.time() > SpamCheck[src].time then SpamCheck[src] = { veh = 0, ped = 0, obj = 0, time = os.time() } end

    local type = GetEntityType(entity)
    local count = SpamCheck[src]
    local limit = 20
    local label = "Entity Spam"

    if type == 1 then count.ped = count.ped + 1; limit = MaxPedsPerSec; label = "Ped Spam"
    elseif type == 2 then count.veh = count.veh + 1; limit = MaxVehiclesPerSec; label = "Vehicle Spam"
    elseif type == 3 then count.obj = count.obj + 1; limit = MaxObjectsPerSec; label = "Prop Spam"
    end

    if (type == 1 and count.ped > limit) or (type == 2 and count.veh > limit) or (type == 3 and count.obj > limit) then
        CancelEvent()
        print("^1[ANTI-CRASH] ^7Bloqueado spawn de ID: " .. src .. " ("..label..")")
        TriggerClientEvent('jeler:mostrarPantalla', src, label)
        return 
    end
    
    local model = GetEntityModel(entity)
    for _, blockedModel in ipairs(Config.BlacklistedEntities) do
        if model == GetHashKey(blockedModel) then 
            CancelEvent()
            TriggerClientEvent('jeler:mostrarPantalla', src, "Blacklisted Prop Detected")
            break 
        end
    end
end)

Citizen.CreateThread(function() while true do Citizen.Wait(60000); SpamCheck = {} end end)

-- ANTI-EXPLOSION
local ExplosionRates = {}
local MaxExplosionsPerSec = 5

AddEventHandler('explosionEvent', function(sender, ev)
    if not sender then CancelEvent(); return end
    for _, type in ipairs(Config.BlacklistedExplosions) do
        if ev.explosionType == type then 
            CancelEvent() 
            AddSuspicion(sender, 100, "Illegal Explosion Type: "..type)
            return 
        end
    end
    if not ExplosionRates[sender] then ExplosionRates[sender] = { count = 0, time = os.time() } end
    if os.time() > ExplosionRates[sender].time then ExplosionRates[sender] = { count = 0, time = os.time() } end
    ExplosionRates[sender].count = ExplosionRates[sender].count + 1
    if ExplosionRates[sender].count > MaxExplosionsPerSec then
        CancelEvent() 
        if ExplosionRates[sender].count > (MaxExplosionsPerSec + 2) then
             TriggerClientEvent('jeler:mostrarPantalla', sender, "Explosion Spam Detected")
        end
    end
end)

AddEventHandler('executeCommand', function(commandSource, command)
    if not commandSource or commandSource == 0 then return end
    local cmd = string.lower(command)
    for _, blockedCmd in ipairs(Config.BlacklistedCommands) do
        if string.find(cmd, blockedCmd) then
            CancelEvent()
            AddSuspicion(commandSource, 100, "Illegal Command Injection")
            return
        end
    end
end)

-- HEURÍSTICA DE COMBATE
AddEventHandler('weaponDamageEvent', function(sender, data)
    if not isAuthenticated then return end
    local victimId = data.hitGlobalId
    local victimPed = GetPlayerPed(victimId)
    local shooter = GetPlayerPed(sender)
    
    if not DoesEntityExist(victimPed) or not IsPedAPlayer(victimPed) then return end
    if data.weaponDamage <= 0 then return end

    local serverCoords = GetEntityCoords(shooter)
    local clientReportedCoords = PlayerPositions[sender] or serverCoords 
    local desyncDist = #(serverCoords - clientReportedCoords)
    
    if desyncDist > Config.MaxDesyncDistance then
        if not IsPedInAnyVehicle(shooter, false) then
             AddSuspicion(sender, 40, "Damage Desync (Dist: "..math.floor(desyncDist).."m)")
        end
    end

    local currentRot = GetEntityRotation(shooter, 2)
    if PlayerRotations[sender] then
        local prevRot = PlayerRotations[sender]
        local deltaYaw = math.abs(currentRot.z - prevRot.z)
        if deltaYaw > 180 then deltaYaw = 360 - deltaYaw end
        if deltaYaw > Config.MaxRotationSpeed then AddSuspicion(sender, 35, "Snap Aim") end
    end
    PlayerRotations[sender] = currentRot

    local damageLimit = 250
    local weaponHash = GetSelectedPedWeapon(shooter)
    local wClass = WeaponGroups[weaponHash] or 'default'
    if wClass == 'sniper' then damageLimit = 400 end
    if data.weaponDamage > damageLimit then AddSuspicion(sender, 100, "Extreme Damage") return end

    local healthBefore = GetEntityHealth(victimPed)
    local armorBefore = GetPedArmour(victimPed)
    SetTimeout(150, function()
        if not DoesEntityExist(victimPed) then return end
        if healthBefore == GetEntityHealth(victimPed) and armorBefore == GetPedArmour(victimPed) then
             if not IsEntityDead(victimPed) then 
                if not GodmodeStrikes[victimId] then GodmodeStrikes[victimId] = 0 end
                GodmodeStrikes[victimId] = GodmodeStrikes[victimId] + 1
                if GodmodeStrikes[victimId] >= Config.GodmodeStrikes then AddSuspicion(victimId, 100, "Godmode") end
             end
        else
            if GodmodeStrikes[victimId] and GodmodeStrikes[victimId] > 0 then GodmodeStrikes[victimId] = GodmodeStrikes[victimId] - 1 end
        end
    end)
    
    local wConfig = Config.WeaponClasses[wClass]
    local ping = GetPlayerPing(sender)
    local tolerance = wConfig.tolerance
    local hitRadius = Config.MaxHitboxRadius
    if IsPedInCover(shooter, 0) then tolerance = 50.0; hitRadius = hitRadius + 0.5 end
    if GetEntitySpeed(shooter) > 2.5 then tolerance = tolerance * 2.0 end
    if ping > Config.PingAssist then tolerance = tolerance * 1.5 end

    local headPos = MathUtils.GetHeadCoords(shooter)
    local hitPos = GetEntityCoords(victimPed)
    if data.hitComponent == 31086 then local s, h = pcall(GetPedBoneCoords, victimPed, 31086, 0.0, 0.0, 0.0); if s then hitPos = h end end
    if #(hitPos - headPos) < 3.0 then return end 

    local bulletVec = MathUtils.NormalizeVector(hitPos - headPos)
    local camDir = MathUtils.RotationToDirection(GetEntityRotation(shooter, 2))
    local missDist = MathUtils.DistanceFromLineToPoint(headPos, camDir, hitPos)
    if missDist > hitRadius then AddSuspicion(sender, Config.MagicBulletSeverity, "Magic Bullet") return end

    local angle = MathUtils.CalculateAngle(bulletVec, camDir)
    if angle > tolerance then
        local excess = angle - tolerance
        AddSuspicion(sender, wConfig.severity + (excess * 2), "Silent Aim")
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

-- WATCHDOG & LIMPIEZA
AddEventHandler('playerJoining', function()
    local src = source
    LastHeartbeat[src] = os.time()
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)
        local now = os.time()
        for _, playerId in ipairs(GetPlayers()) do
            local src = tonumber(playerId)
            if LastHeartbeat[src] then
                local timeSinceLast = now - LastHeartbeat[src]
                local limit = PlayerSecurity[src] and Config.HeartbeatTimeout or Config.LoginTimeout
                if timeSinceLast > limit then
                    if PlayerSecurity[src] then
                        print("^1[WATCHDOG] ^7ID "..src.." resource stopped (Jugando).")
                        DropPlayer(src, "🛡️ Jeler AC: Security Resource Stopped")
                    else
                        print("^3[WATCHDOG] ^7ID "..src.." timeout (Cargando).")
                        DropPlayer(src, "🛡️ Jeler AC: Connection Timeout")
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStart', function(res) if GetCurrentResourceName() == res then isAuthenticated = true end end)

AddEventHandler('playerDropped', function() 
    local src = source
    LastHeartbeat[src] = nil
    PlayerSecurity[src] = nil
    PlayerRotations[src] = nil
    PlayerSuspicion[src] = nil
    PlayerStats[src] = nil
    EntityRates[src] = nil
    ExplosionRates[src] = nil
    SpamGuard[src] = nil
end)

RegisterNetEvent('jeler:heartbeat')
AddEventHandler('jeler:heartbeat', function(token, seq, clientResCount)
    local src = source
    if not SpamGuard[src] then SpamGuard[src] = 0 end
    if os.clock() - SpamGuard[src] < 1.0 then return end
    SpamGuard[src] = os.clock()

    if not ValidateToken(src, token, seq) then return end
    LastHeartbeat[src] = os.time()
    
    local serverResCount = GetNumResources()
    if clientResCount and (clientResCount > serverResCount + 2) then
        AddSuspicion(src, 100, "Resource Injection")
    end
end)