print("^2>>> JELER AC: CLIENTE CARGADO EXITOSAMENTE (v10.0 - FULL TEST MODE) <<<")

local SecurityToken = nil
local CurrentSeq = 0 
local initialized = false
local HasSpawned = false 
local ProtectionTimer = 0
local GodmodeForceCounter = 0

-- 1. SOLICITAR TOKEN AL INICIAR
Citizen.CreateThread(function()
    Citizen.Wait(2000) 
    print("Jeler AC: Requesting Security Token...")
    TriggerServerEvent('jeler:requestToken')
end)

-- [FIX REINICIO]
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    if NetworkIsPlayerActive(PlayerId()) then
        HasSpawned = true
        ProtectionTimer = GetGameTimer() + 10000 
        print("Jeler AC: Reinicio detectado. Protección de 10s activa.")
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
    ProtectionTimer = GetGameTimer() + 20000 
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

-- 4. ESCANER DE GLOBALES
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000) 
        if initialized then
            for _, globalName in ipairs(Config.BlacklistedGlobals) do
                if _G[globalName] ~= nil then
                    TriggerServerEvent('jeler:flag', SecurityToken, 'Lua Injector Detected: '..globalName)
                end
            end
        end
    end
end)

-- 5. DETECTORES DE TECLAS [OPTIMIZADO]
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10) -- Optimización de CPU (0 -> 10)
        if initialized and SecurityToken then
            for _, entry in ipairs(Config.BlacklistedKeys) do
                if IsControlJustPressed(0, entry.key) then
                    TriggerServerEvent('jeler:flag', SecurityToken, 'Restricted Key: '..entry.name)
                end
            end
        end
    end
end)

-- 6. LOOP PRINCIPAL (INTERNAL CHEATS)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) 
        if initialized and SecurityToken then
            
            if HasSpawned then
                local pid = PlayerId()
                local ped = PlayerPedId()

                if NetworkIsPlayerActive(pid) and not IsPlayerDead(ped) and not IsPlayerSwitchInProgress() then
                    
                    if GetPlayerInvincible(pid) then
                        if GetGameTimer() > ProtectionTimer then
                            SetPlayerInvincible(pid, false)
                            SetEntityInvincible(ped, false)
                            GodmodeForceCounter = GodmodeForceCounter + 1
                            if GodmodeForceCounter >= 10 then
                                TriggerServerEvent('jeler:flag', SecurityToken, 'Godmode (Persistent)')
                                GodmodeForceCounter = 0 
                            end
                        end
                    else
                        if GodmodeForceCounter > 0 then GodmodeForceCounter = 0 end
                    end
                end
                
                if GetGameTimer() > ProtectionTimer then
                    local currentWeapon = GetSelectedPedWeapon(ped)
                    if GetPlayerWeaponDamageModifier(pid) > 1.2 then TriggerServerEvent('jeler:flag', SecurityToken, 'Damage Modifier (Player)') end
                    if GetWeaponDamageModifier(currentWeapon) > 1.2 then TriggerServerEvent('jeler:flag', SecurityToken, 'Damage Modifier (Weapon)') end

                    local damageType = GetWeaponDamageType(currentWeapon)
                    local weaponGroup = GetWeapontypeGroup(currentWeapon)
                    local isExplosiveWeapon = (weaponGroup == 970310034 or weaponGroup == 1159398588) 
                    if (damageType == 4 or damageType == 5) and not isExplosiveWeapon then
                        TriggerServerEvent('jeler:flag', SecurityToken, 'Explosive/Fire Ammo')
                    end
                    
                    local speed = GetEntitySpeed(ped)
                    if not IsPedInAnyVehicle(ped, false) and not IsPedFalling(ped) and not IsPedRagdoll(ped) then
                        if IsPedWalking(ped) and speed > Config.MaxWalkSpeed then TriggerServerEvent('jeler:flag', SecurityToken, 'Speed Walk') end
                        if (IsPedRunning(ped) or IsPedSprinting(ped)) and speed > Config.MaxSprintSpeed then TriggerServerEvent('jeler:flag', SecurityToken, 'Speed Sprint') end
                    end

                    if IsPedJumping(ped) and GetPlayerSuperJumpEnabled(pid) then TriggerServerEvent('jeler:flag', SecurityToken, 'Super Jump') end

                    if IsPedInAnyVehicle(ped, false) then
                        local veh = GetVehiclePedIsUsing(ped)
                        if GetVehicleTopSpeedModifier(veh) > 10.0 then TriggerServerEvent('jeler:flag', SecurityToken, 'Vehicle Speed Mod') end
                        if GetVehicleCheatPowerIncrease(veh) > 1.0 then TriggerServerEvent('jeler:flag', SecurityToken, 'Vehicle Power Mod') end
                    end
                end
            end
        end
    end
end)

-- 7. DETECTOR ANTI-EXTERNAL (GODMODE)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) 
        if initialized and SecurityToken and HasSpawned then
            local ped = PlayerPedId()
            if not IsPlayerDead(ped) and GetGameTimer() > ProtectionTimer then
                if GetEntityHealth(ped) >= (GetEntityMaxHealth(ped) - 2) then
                    if HasEntityBeenDamagedByAnyPed(ped) or HasEntityBeenDamagedByAnyVehicle(ped) or HasEntityBeenDamagedByAnyObject(ped) then
                        TriggerServerEvent('jeler:flag', SecurityToken, 'External Godmode')
                        ClearEntityLastDamageEntity(ped)
                    end
                end
            end
        end
    end
end)

-- 8. DETECTOR DE NOCLIP (POSICIÓN)
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
                    if dist > 4.0 then
                        local height = GetEntityHeightAboveGround(ped)
                        if not IsPedInAnyVehicle(ped, false) and height > 3.0 then
                            if not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) and not IsPedSwimming(ped) then
                                TriggerServerEvent('jeler:flag', SecurityToken, 'Noclip (Air Movement)')
                            end
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

-- 9. GESTOR DE PANTALLA
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
-- ZONA DE COMANDOS DE PRUEBA
-- =====================================================
RegisterCommand("testac", function()
    if initialized and SecurityToken then TriggerServerEvent('jeler:flag', SecurityToken, 'TEST MANUAL') end
end)

RegisterCommand("hack_godmode", function()
    local ped = PlayerPedId()
    Citizen.CreateThread(function() while true do Citizen.Wait(0); SetEntityInvincible(ped, true) end end)
end)

RegisterCommand("simular_external", function()
    local ped = PlayerPedId()
    Citizen.CreateThread(function() while true do Citizen.Wait(0); if GetEntityHealth(ped) < 200 then SetEntityHealth(ped, 200) end end end)
end)

RegisterCommand("test_noclip", function()
    local ped = PlayerPedId()
    Citizen.CreateThread(function()
        for i=1, 20 do
            local fwd = GetEntityForwardVector(ped)
            local newPos = GetEntityCoords(ped) + (fwd * 2.0) + vector3(0,0,0.5) 
            SetEntityCoords(ped, newPos.x, newPos.y, newPos.z, false, false, false, false)
            Citizen.Wait(50)
        end
    end)
end)

local noclipActive = false
RegisterCommand("live_noclip", function()
    noclipActive = not noclipActive
    local ped = PlayerPedId()
    if noclipActive then SetEntityInvincible(ped, true); SetEntityVisible(ped, false, false)
    else SetEntityInvincible(ped, false); SetEntityVisible(ped, true, false); FreezeEntityPosition(ped, false); return end
    Citizen.CreateThread(function()
        local speed = 1.0 
        while noclipActive do
            Citizen.Wait(0)
            FreezeEntityPosition(ped, true)
            local camRot = GetGameplayCamRot(2)
            local radRot = vector3(math.rad(camRot.x), math.rad(camRot.y), math.rad(camRot.z))
            local forwardDir = vector3(-math.sin(radRot.z) * math.abs(math.cos(radRot.x)), math.cos(radRot.z) * math.abs(math.cos(radRot.x)), math.sin(radRot.x))
            local rightDir = vector3(math.cos(radRot.z), math.sin(radRot.z), 0)
            local newPos = GetEntityCoords(ped)
            local moved = false
            local multiplier = IsControlPressed(0, 21) and 4.0 or 1.0
            if IsControlPressed(0, 32) then newPos = newPos + (forwardDir * speed * multiplier * 0.5); moved = true end
            if IsControlPressed(0, 33) then newPos = newPos - (forwardDir * speed * multiplier * 0.5); moved = true end
            if IsControlPressed(0, 34) then newPos = newPos - (rightDir * speed * multiplier * 0.5); moved = true end
            if IsControlPressed(0, 35) then newPos = newPos + (rightDir * speed * multiplier * 0.5); moved = true end
            if IsDisabledControlPressed(0, 22) then newPos = newPos + vector3(0,0, speed * multiplier * 0.5); moved = true end
            if IsDisabledControlPressed(0, 36) then newPos = newPos - vector3(0,0, speed * multiplier * 0.5); moved = true end
            if moved then SetEntityCoordsNoOffset(ped, newPos.x, newPos.y, newPos.z, true, true, true); SetEntityHeading(ped, camRot.z) end
        end
    end)
end)

RegisterCommand("test_crash", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = GetHashKey("prop_barrier_work06a") 
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(0) end
    Citizen.CreateThread(function()
        for i=1, 50 do
            CreateObject(model, coords.x + math.random(-5,5), coords.y + math.random(-5,5), coords.z, true, true, false)
            Citizen.Wait(10) 
        end
    end)
end)

RegisterCommand("test_veh_ban", function()
    local ped = PlayerPedId()
    local hash = GetHashKey("rhino") 
    RequestModel(hash)
    while not HasModelLoaded(hash) do Citizen.Wait(0) end
    local veh = CreateVehicle(hash, GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    SetPedIntoVehicle(ped, veh, -1)
end)

RegisterCommand("test_wep_ban", function()
    local ped = PlayerPedId()
    local hash = GetHashKey("WEAPON_MINIGUN") 
    GiveWeaponToPed(ped, hash, 9999, false, true)
end)

RegisterCommand("test_speed_foot", function()
    local pid = PlayerId()
    SetRunSprintMultiplierForPlayer(pid, 1.49)
    Citizen.SetTimeout(10000, function() SetRunSprintMultiplierForPlayer(pid, 1.0) end)
end)

RegisterCommand("test_speed_veh", function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsUsing(ped)
    if veh ~= 0 then
        SetVehicleCheatPowerIncrease(veh, 50.0)
        Citizen.SetTimeout(5000, function() SetVehicleCheatPowerIncrease(veh, 1.0) end)
    end
end)

RegisterCommand("test_gun", function()
    local ped = PlayerPedId()
    local weaponHash = GetHashKey("WEAPON_COMBATPISTOL") 
    GiveWeaponToPed(ped, weaponHash, 9999, false, true)
end)