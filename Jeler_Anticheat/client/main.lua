print("^2>>> JELER AC: CLIENTE CARGADO EXITOSAMENTE (v14.0 - AGGRESSIVE SCAN) <<<")

local SecurityToken = nil
local CurrentSeq = 0 
local initialized = false
local HasSpawned = false 
local ProtectionTimer = 0
local GodmodeForceCounter = 0
local BypassAmmo = false -- Variable para permitir items legales

-- ENCRIPTACIÓN
local function XOREncrypt(str, key)
    local res = {}
    for i = 1, #str do
        local keyByte = string.byte(key, (i - 1) % #key + 1)
        table.insert(res, string.char(string.byte(str, i) ~ keyByte))
    end
    return table.concat(res)
end

-- HELPER ENCRIPTADO
local function TriggerFlag(reason)
    if initialized and SecurityToken then
        local encryptedMsg = XOREncrypt(reason, SecurityToken)
        TriggerServerEvent('jeler:flag', SecurityToken, encryptedMsg)
        -- Print local para confirmar detección en F8
        print("^1[JELER DETECT] ^7Flag Enviada: " .. reason)
    end
end

-- EVENTO BYPASS MUNICIÓN (Para items legales como 'Bala Universal')
RegisterNetEvent('jeler:setAmmoBypass')
AddEventHandler('jeler:setAmmoBypass', function(status)
    BypassAmmo = status
    if status then print("Jeler AC: Bypass de munición activado (Item Legal)") end
end)

-- 1. SOLICITAR TOKEN
Citizen.CreateThread(function()
    Citizen.Wait(2000) 
    print("Jeler AC: Requesting Security Token...")
    TriggerServerEvent('jeler:requestToken')
end)

-- FIX REINICIO (Timer reducido a 5s para detectar pruebas rápidas)
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    if NetworkIsPlayerActive(PlayerId()) then
        HasSpawned = true
        ProtectionTimer = GetGameTimer() + 5000 
        print("Jeler AC: Reinicio detectado. Escaneo agresivo en 5s.")
    end
end)

-- 2. RECIBIR TOKEN
RegisterNetEvent('jeler:setToken')
AddEventHandler('jeler:setToken', function(token)
    SecurityToken = token
    initialized = true
    print("Jeler AC: Protected & Running.")
end)

RegisterNetEvent('jeler:updateToken')
AddEventHandler('jeler:updateToken', function(newToken)
    SecurityToken = newToken
    CurrentSeq = 0 
end)

AddEventHandler('playerSpawned', function()
    HasSpawned = true
    ProtectionTimer = GetGameTimer() + 5000 -- Reducido a 5s
    GodmodeForceCounter = 0 
end)

-- 3. HEARTBEAT
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(20000)
        if initialized and SecurityToken then
            CurrentSeq = CurrentSeq + 1
            local resCount = GetNumResources()
            TriggerServerEvent('jeler:heartbeat', SecurityToken, CurrentSeq, resCount)
        end
    end
end)

-- 4. ESCANER DE GLOBALES (Inyectores Lua)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) 
        if initialized then
            for _, globalName in ipairs(Config.BlacklistedGlobals) do
                if _G[globalName] ~= nil then
                    TriggerFlag('Lua Injector Detected: '..globalName)
                end
            end
        end
    end
end)

-- 5. DETECTORES DE TECLAS
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10) 
        if initialized and SecurityToken then
            for _, entry in ipairs(Config.BlacklistedKeys) do
                if IsControlJustPressed(0, entry.key) then
                    TriggerFlag('Restricted Key: '..entry.name)
                end
            end
        end
    end
end)

-- 6. LOOP AGRESIVO (INTERNAL CHEATS / MEMORY MODIFIERS) - 200ms
-- Acelerado para detectar cambios rápidos de memoria (/ext_dmg)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200) 
        if initialized and SecurityToken and HasSpawned then
            
            -- Solo escaneamos si pasó el tiempo de protección
            if GetGameTimer() > ProtectionTimer then
                local pid = PlayerId()
                local ped = PlayerPedId()

                if NetworkIsPlayerActive(pid) and not IsPlayerDead(ped) and not IsPlayerSwitchInProgress() then
                    
                    -- Check Godmode Interno
                    if GetPlayerInvincible(pid) then
                         SetPlayerInvincible(pid, false)
                         SetEntityInvincible(ped, false)
                         GodmodeForceCounter = GodmodeForceCounter + 1
                         if GodmodeForceCounter >= 10 then
                             TriggerFlag('Godmode (Persistent)')
                             GodmodeForceCounter = 0 
                         end
                    else
                        if GodmodeForceCounter > 0 then GodmodeForceCounter = 0 end
                    end

                    -- Check Damage Modifier (Player)
                    if GetPlayerWeaponDamageModifier(pid) > 1.2 then 
                        TriggerFlag('Damage Modifier (Player)') 
                    end
                    
                    -- Check Damage Modifier (Weapon)
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    if GetWeaponDamageModifier(currentWeapon) > 1.2 then 
                        TriggerFlag('Damage Modifier (Weapon)') 
                    end

                    -- Check Munición Explosiva
                    local damageType = GetWeaponDamageType(currentWeapon)
                    local weaponGroup = GetWeapontypeGroup(currentWeapon)
                    local isExplosiveWeapon = (weaponGroup == 970310034 or weaponGroup == 1159398588) 
                    if (damageType == 4 or damageType == 5) and not isExplosiveWeapon then
                        TriggerFlag('Explosive/Fire Ammo')
                    end
                    
                    -- Check Super Jump
                    if IsPedJumping(ped) and GetPlayerSuperJumpEnabled(pid) then 
                        TriggerFlag('Super Jump') 
                    end

                    -- Check Vehicle Mods
                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsUsing(ped)
                        if GetVehicleTopSpeedModifier(veh) > 10.0 then TriggerFlag('Vehicle Speed Mod') end
                        if GetVehicleCheatPowerIncrease(veh) > 1.0 then TriggerFlag('Vehicle Power Mod') end
                    end
                end
            end
        end
    end
end)

-- 7. DETECTOR ANTI-EXTERNAL (GODMODE - HEALTH FREEZE)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) 
        if initialized and SecurityToken and HasSpawned then
            local ped = PlayerPedId()
            if not IsPlayerDead(ped) and GetGameTimer() > ProtectionTimer then
                if GetEntityHealth(ped) >= (GetEntityMaxHealth(ped) - 2) then
                    if HasEntityBeenDamagedByAnyPed(ped) or HasEntityBeenDamagedByAnyVehicle(ped) or HasEntityBeenDamagedByAnyObject(ped) then
                        TriggerFlag('External Godmode (Health Lock)')
                        ClearEntityLastDamageEntity(ped)
                    end
                end
            end
        end
    end
end)

-- 8. DETECTOR DE MOVIMIENTO MEJORADO (Detecta /ext_lag)
local lastCoords = nil 
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) -- Revisamos cada medio segundo
        if initialized and SecurityToken and HasSpawned then
            local ped = PlayerPedId()
            
            if not IsPlayerDead(ped) and GetGameTimer() > ProtectionTimer then
                local currentCoords = GetEntityCoords(ped)
                
                if lastCoords then
                    local dist = #(currentCoords - lastCoords)
                    local isVeh = IsPedInAnyVehicle(ped, false)
                    
                    -- A) DETECCIÓN DE LAG SWITCH / TELEPORT (Distancia Extrema)
                    -- Si se mueve más de 15 metros en 0.5s y no está en auto
                    if not isVeh and dist > 15.0 then
                        if not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) then
                            TriggerFlag('Teleport / Lag Switch Detected ('..math.floor(dist)..'m)')
                        end
                    end

                    -- B) DETECCIÓN DE NOCLIP (Vuelo)
                    if dist > 4.0 then
                        local height = GetEntityHeightAboveGround(ped)
                        if not isVeh and height > 3.0 then
                            if not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) and not IsPedSwimming(ped) and not IsPedRagdoll(ped) then
                                TriggerFlag('Noclip (Air Movement)')
                            end
                        end
                    end
                    
                    -- C) DETECCIÓN DE SPEEDHACK (Suelo)
                    -- Límite configurado en config (ej: 12.0)
                    local maxDistAllowed = (Config.MaxRunSpeed or 12.0) * 0.5
                    if not isVeh and dist > maxDistAllowed and dist <= 15.0 then
                         if not IsPedFalling(ped) and not IsPedRagdoll(ped) and not IsPedJumping(ped) then
                             TriggerFlag('Speedhack (Ground Limit Exceeded)')
                         end
                    end
                end
                lastCoords = currentCoords
            else
                lastCoords = nil
            end
        end
    end
end)

-- 9. DETECCIÓN DE MUNICIÓN INFINITA Y VISIONES (CON BYPASS)
Citizen.CreateThread(function()
    local lastAmmo = nil
    while true do
        Citizen.Wait(200) -- Acelerado a 200ms para detectar /ext_ammo
        if initialized and SecurityToken and HasSpawned and GetGameTimer() > ProtectionTimer then
            local ped = PlayerPedId()
            
            -- Visiones
            if GetUsingnightvision(true) then TriggerFlag('Night Vision Detected'); SetNightvision(false) end
            if GetUsingseethrough(true) then TriggerFlag('Thermal Vision Detected'); SetSeethrough(false) end

            -- Munición Infinita (Solo si NO tiene bypass activado)
            if IsPedShooting(ped) and not BypassAmmo then
                local currentWeapon = GetSelectedPedWeapon(ped)
                local _, clipAmmo = GetAmmoInClip(ped, currentWeapon)

                if lastAmmo ~= nil and currentWeapon == lastAmmo.weapon then
                    -- Si dispara y las balas no bajan (o suben)
                    if clipAmmo >= lastAmmo.clip and clipAmmo > 0 and not IsPedReloading(ped) then
                        local group = GetWeapontypeGroup(currentWeapon)
                        if group ~= -1609580060 and group ~= -728555052 then 
                            TriggerFlag('Infinite Ammo (No Reload)')
                        end
                    end
                end
                lastAmmo = { weapon = currentWeapon, clip = clipAmmo }
            else
                -- Si deja de disparar, actualizamos referencia
                if not IsPedShooting(ped) then
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    local _, clipAmmo = GetAmmoInClip(ped, currentWeapon)
                    lastAmmo = { weapon = currentWeapon, clip = clipAmmo }
                end
            end
        end
    end
end)

-- 10. GESTOR DE PANTALLA
RegisterNetEvent('jeler:mostrarPantalla')
AddEventHandler('jeler:mostrarPantalla', function(reason)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "open", reason = reason, banId = "TEST-BAN-" .. math.random(1000,9999) })
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)

-- =====================================================
-- COMANDOS DE PRUEBA (ACTUALIZADOS)
-- =====================================================

RegisterCommand("testac", function()
    if initialized and SecurityToken then TriggerFlag('TEST MANUAL ENCRIPTADO') end
end)

-- 1. EXTERNAL GODMODE (HEALTH FREEZE)
local externalGodActive = false
RegisterCommand("ext_godmode", function()
    externalGodActive = not externalGodActive
    if externalGodActive then
        print("^1[TEST EXTERNAL] ^7Health Lock (Memory Freeze) ACTIVADO.")
        local ped = PlayerPedId()
        Citizen.CreateThread(function()
            while externalGodActive do
                Citizen.Wait(0)
                if GetEntityHealth(ped) < 200 then SetEntityHealth(ped, 200) end
            end
        end)
    else
        print("^2[TEST EXTERNAL] ^7Health Lock DESACTIVADO.")
    end
end)

-- 2. EXTERNAL DAMAGE BOOST (MEMORY WRITE)
RegisterCommand("ext_dmg", function()
    local pid = PlayerId()
    print("^1[TEST EXTERNAL] ^7Inyectando valor 10.0 en WeaponDamageModifier...")
    SetPlayerWeaponDamageModifier(pid, 10.0)
    Citizen.SetTimeout(5000, function()
        SetPlayerWeaponDamageModifier(pid, 1.0)
        print("^2[TEST EXTERNAL] ^7Valor restaurado.")
    end)
end)

-- 3. EXTERNAL SILENT AIM (PACKET MANIPULATION)
RegisterCommand("ext_silent", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local retval, target = GetClosestPed(coords.x, coords.y, coords.z, 50.0, 1, 0, 0, 0, -1)
    if DoesEntityExist(target) and target ~= ped then
        print("^1[TEST EXTERNAL] ^7Simulando Silent Aim...")
        local headPos = GetPedBoneCoords(target, 31086, 0, 0, 0)
        ShootSingleBulletBetweenCoords(coords.x, coords.y, coords.z, headPos.x, headPos.y, headPos.z, 100, true, GetSelectedPedWeapon(ped), ped, true, true, -1.0)
    else
        print("^3[TEST] ^7Necesitas un objetivo cerca.")
    end
end)

-- 4. EXTERNAL NO RELOAD (AMMO FREEZE)
local externalAmmoActive = false
RegisterCommand("ext_ammo", function()
    externalAmmoActive = not externalAmmoActive
    local ped = PlayerPedId()
    local wep = GetSelectedPedWeapon(ped)
    if externalAmmoActive then
        print("^1[TEST EXTERNAL] ^7Ammo Address Freeze ACTIVADO.")
        Citizen.CreateThread(function()
            while externalAmmoActive do
                Citizen.Wait(0)
                if IsPedShooting(ped) then SetPedAmmo(ped, wep, 200) end
            end
        end)
    else
        print("^2[TEST EXTERNAL] ^7Ammo Freeze DESACTIVADO.")
    end
end)

-- 5. EXTERNAL LAG SWITCH (PACKET CHOKE)
-- Ahora detectado por el bloque 8 (Dist > 15m)
RegisterCommand("ext_lag", function()
    print("^1[TEST EXTERNAL] ^7Simulando Lag Switch (Desync de posición 16m)...")
    local ped = PlayerPedId()
    local pos = GetEntityCoords(ped)
    Citizen.SetTimeout(1000, function()
        SetEntityCoords(ped, pos.x + 16.0, pos.y, pos.z, false, false, false, false)
        print("^1[TEST] ^7Teletransporte realizado.")
    end)
end)

-- TESTS BÁSICOS
RegisterCommand("test_speed_foot", function()
    local pid = PlayerId()
    SetRunSprintMultiplierForPlayer(pid, 1.49)
    Citizen.SetTimeout(5000, function() SetRunSprintMultiplierForPlayer(pid, 1.0) end)
end)

RegisterCommand("test_veh_ban", function()
    local ped = PlayerPedId()
    local hash = GetHashKey("rhino") 
    RequestModel(hash)
    while not HasModelLoaded(hash) do Citizen.Wait(0) end
    local veh = CreateVehicle(hash, GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    SetPedIntoVehicle(ped, veh, -1)
end)

RegisterCommand("test_gun", function()

    local ped = PlayerPedId()

    local weaponHash = GetHashKey("WEAPON_COMBATPISTOL")

    GiveWeaponToPed(ped, weaponHash, 9999, false, true)

end)

-- =====================================================
-- TEST DE DAÑO INTELIGENTE (BYPASS CLIENTE -> TEST SERVER)
-- =====================================================
-- Este comando sube el daño SOLO cuando aprietas disparar y lo baja al soltar.
-- Intenta evadir el escáner de memoria (Loop 6) para probar si el SERVIDOR detecta el daño excesivo.

local smartDmgActive = false
RegisterCommand("ext_smartdmg", function()
    smartDmgActive = not smartDmgActive
    local pid = PlayerId()
    
    if smartDmgActive then
        print("^1[TEST] ^7Smart Damage (Trigger Mode) ACTIVADO. Dispara a un enemigo.")
        
        Citizen.CreateThread(function()
            while smartDmgActive do
                Citizen.Wait(0)
                -- Solo aumentamos el daño si está disparando activamente
                if IsPedShooting(PlayerPedId()) then
                    SetPlayerWeaponDamageModifier(pid, 100.0) -- Daño x100 instantáneo
                else
                    -- Si no dispara, lo mantenemos normal para que el escáner de memoria no lo detecte
                    SetPlayerWeaponDamageModifier(pid, 1.0) 
                end
            end
            -- Aseguramos reset al apagar
            SetPlayerWeaponDamageModifier(pid, 1.0)
        end)
    else
        print("^2[TEST] ^7Smart Damage DESACTIVADO.")
        SetPlayerWeaponDamageModifier(pid, 1.0)
    end
end)
