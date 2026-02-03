print("^2>>> JELER AC: CLIENTE CARGADO (v14.5 FINAL) <<<")

local SecurityToken = nil
local CurrentSeq = 0 
local initialized = false
local HasSpawned = false 
local ProtectionTimer = 0
local GodmodeForceCounter = 0
local BypassAmmo = false 

local function XOREncrypt(str, key)
    local res = {}
    for i = 1, #str do
        local keyByte = string.byte(key, (i - 1) % #key + 1)
        table.insert(res, string.char(string.byte(str, i) ~ keyByte))
    end
    return table.concat(res)
end

local function TriggerFlag(reason)
    if initialized and SecurityToken then
        local encryptedMsg = XOREncrypt(reason, SecurityToken)
        TriggerServerEvent('jeler:flag', SecurityToken, encryptedMsg)
    end
end

RegisterNetEvent('jeler:setAmmoBypass')
AddEventHandler('jeler:setAmmoBypass', function(status) BypassAmmo = status end)

Citizen.CreateThread(function()
    Citizen.Wait(2000) 
    TriggerServerEvent('jeler:requestToken')
end)

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    if NetworkIsPlayerActive(PlayerId()) then
        HasSpawned = true
        ProtectionTimer = GetGameTimer() + 5000 
    end
end)

RegisterNetEvent('jeler:setToken')
AddEventHandler('jeler:setToken', function(token)
    SecurityToken = token
    initialized = true
end)

RegisterNetEvent('jeler:updateToken')
AddEventHandler('jeler:updateToken', function(newToken)
    SecurityToken = newToken
    CurrentSeq = 0 
end)

AddEventHandler('playerSpawned', function()
    HasSpawned = true
    ProtectionTimer = GetGameTimer() + 5000
    GodmodeForceCounter = 0 
end)

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

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) 
        if initialized then
            for _, globalName in ipairs(Config.BlacklistedGlobals) do
                if _G[globalName] ~= nil then TriggerFlag('Lua Injector: '..globalName) end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10) 
        if initialized and SecurityToken then
            for _, entry in ipairs(Config.BlacklistedKeys) do
                if IsControlJustPressed(0, entry.key) then TriggerFlag('Key: '..entry.name) end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(200) 
        if initialized and SecurityToken and HasSpawned then
            if GetGameTimer() > ProtectionTimer then
                local pid = PlayerId()
                local ped = PlayerPedId()

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

                if GetPlayerWeaponDamageModifier(pid) > 1.2 then TriggerFlag('Damage Modifier (Player)') end
                
                local currentWeapon = GetSelectedPedWeapon(ped)
                if GetWeaponDamageModifier(currentWeapon) > 1.2 then TriggerFlag('Damage Modifier (Weapon)') end

                local damageType = GetWeaponDamageType(currentWeapon)
                local weaponGroup = GetWeapontypeGroup(currentWeapon)
                local isExplosiveWeapon = (weaponGroup == 970310034 or weaponGroup == 1159398588) 
                if (damageType == 4 or damageType == 5) and not isExplosiveWeapon then
                    TriggerFlag('Explosive/Fire Ammo')
                end
                
                if IsPedJumping(ped) and GetPlayerSuperJumpEnabled(pid) then TriggerFlag('Super Jump') end

                if IsPedInAnyVehicle(ped, false) then
                    local veh = GetVehiclePedIsUsing(ped)
                    if GetVehicleTopSpeedModifier(veh) > 10.0 then TriggerFlag('Vehicle Speed Mod') end
                    if GetVehicleCheatPowerIncrease(veh) > 1.0 then TriggerFlag('Vehicle Power Mod') end
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) 
        if initialized and SecurityToken and HasSpawned then
            local ped = PlayerPedId()
            if not IsPlayerDead(ped) and GetGameTimer() > ProtectionTimer then
                if GetEntityHealth(ped) >= (GetEntityMaxHealth(ped) - 2) then
                    if HasEntityBeenDamagedByAnyPed(ped) or HasEntityBeenDamagedByAnyVehicle(ped) or HasEntityBeenDamagedByAnyObject(ped) then
                        TriggerFlag('External Godmode')
                        ClearEntityLastDamageEntity(ped)
                    end
                end
            end
        end
    end
end)

local lastCoords = nil 
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500)
        if initialized and SecurityToken and HasSpawned then
            local ped = PlayerPedId()
            if not IsPlayerDead(ped) and GetGameTimer() > ProtectionTimer then
                local currentCoords = GetEntityCoords(ped)
                if lastCoords then
                    local dist = #(currentCoords - lastCoords)
                    local isVeh = IsPedInAnyVehicle(ped, false)
                    
                    if not isVeh and dist > 15.0 then
                        if not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) then
                            TriggerFlag('Lag Switch ('..math.floor(dist)..'m)')
                        end
                    end

                    if dist > 4.0 then
                        local height = GetEntityHeightAboveGround(ped)
                        if not isVeh and height > 3.0 then
                            if not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) and not IsPedSwimming(ped) and not IsPedRagdoll(ped) then
                                TriggerFlag('Noclip')
                            end
                        end
                    end
                    
                    local maxDistAllowed = (Config.MaxRunSpeed or 12.0) * 0.5
                    if not isVeh and dist > maxDistAllowed and dist <= 15.0 then
                         if not IsPedFalling(ped) and not IsPedRagdoll(ped) and not IsPedJumping(ped) then
                             TriggerFlag('Speedhack')
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

Citizen.CreateThread(function()
    local lastAmmo = nil
    while true do
        Citizen.Wait(200)
        if initialized and SecurityToken and HasSpawned and GetGameTimer() > ProtectionTimer then
            local ped = PlayerPedId()
            
            if GetUsingnightvision(true) then TriggerFlag('Night Vision'); SetNightvision(false) end
            if GetUsingseethrough(true) then TriggerFlag('Thermal Vision'); SetSeethrough(false) end

            if IsPedShooting(ped) and not BypassAmmo then
                local currentWeapon = GetSelectedPedWeapon(ped)
                local _, clipAmmo = GetAmmoInClip(ped, currentWeapon)

                if lastAmmo ~= nil and currentWeapon == lastAmmo.weapon then
                    if clipAmmo >= lastAmmo.clip and clipAmmo > 0 and not IsPedReloading(ped) then
                        local group = GetWeapontypeGroup(currentWeapon)
                        if group ~= -1609580060 and group ~= -728555052 then 
                            TriggerFlag('Infinite Ammo')
                        end
                    end
                end
                lastAmmo = { weapon = currentWeapon, clip = clipAmmo }
            else
                if not IsPedShooting(ped) then
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    local _, clipAmmo = GetAmmoInClip(ped, currentWeapon)
                    lastAmmo = { weapon = currentWeapon, clip = clipAmmo }
                end
            end
        end
    end
end)

RegisterNetEvent('jeler:mostrarPantalla')
AddEventHandler('jeler:mostrarPantalla', function(reason)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "open", reason = reason, banId = "BAN-" .. math.random(1000,9999) })
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
