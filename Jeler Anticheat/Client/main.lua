local SecurityToken = nil
local CurrentSeq = 0 
local initialized = false

-- 1. SOLICITAR TOKEN
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    print("Jeler AC: Requesting Security Token...")
    TriggerServerEvent('jeler:requestToken')
end)

-- 2. RECIBIR TOKEN INICIAL
RegisterNetEvent('jeler:setToken')
AddEventHandler('jeler:setToken', function(token)
    SecurityToken = token
    CurrentSeq = 0
    initialized = true
    print("Jeler AC: Protected & Running.")
end)

-- 3. ACTUALIZAR TOKEN (ROTACIÓN)
RegisterNetEvent('jeler:updateToken')
AddEventHandler('jeler:updateToken', function(newToken)
    SecurityToken = newToken
    CurrentSeq = 0 -- Sincronizar secuencia con server
end)

-- 4. HEARTBEAT SEGURO (CON SECUENCIA)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(20000)
        if initialized and SecurityToken then
            CurrentSeq = CurrentSeq + 1
            TriggerServerEvent('jeler:heartbeat', SecurityToken, CurrentSeq)
        end
    end
end)

-- 5. DETECTORES
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        if initialized and SecurityToken then
            for _, entry in ipairs(Config.BlacklistedKeys) do
                if IsControlJustPressed(0, entry.key) then
                    TriggerServerEvent('jeler:flag', SecurityToken, 'Restricted Key: '..entry.name)
                end
            end
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if initialized and SecurityToken then
            local pid = PlayerId()
            local ped = PlayerPedId()
            
            if GetPlayerInvincible(pid) then TriggerServerEvent('jeler:flag', SecurityToken, 'Godmode (Native Flag)') end
            
            local currentWeapon = GetSelectedPedWeapon(ped)
            if GetPlayerWeaponDamageModifier(pid) > 1.2 then TriggerServerEvent('jeler:flag', SecurityToken, 'Damage Modifier (Player)') end
            if GetWeaponDamageModifier(currentWeapon) > 1.2 then TriggerServerEvent('jeler:flag', SecurityToken, 'Damage Modifier (Weapon)') end

            local damageType = GetWeaponDamageType(currentWeapon)
            local weaponGroup = GetWeapontypeGroup(currentWeapon)
            local isExplosiveWeapon = (weaponGroup == 970310034 or weaponGroup == 1159398588) 
            if (damageType == 4 or damageType == 5) and not isExplosiveWeapon then
                TriggerServerEvent('jeler:flag', SecurityToken, 'Explosive/Fire Ammo Detected')
            end
            
            local speed = GetEntitySpeed(ped)
            if not IsPedInAnyVehicle(ped, false) and not IsPedFalling(ped) and not IsPedRagdoll(ped) then
                if IsPedWalking(ped) and speed > Config.MaxWalkSpeed then TriggerServerEvent('jeler:flag', SecurityToken, 'Speed Walk') end
                if (IsPedRunning(ped) or IsPedSprinting(ped)) and speed > Config.MaxSprintSpeed then TriggerServerEvent('jeler:flag', SecurityToken, 'Speed Sprint') end
            end

            if IsPedJumping(ped) and GetPlayerSuperJumpEnabled(pid) then TriggerServerEvent('jeler:flag', SecurityToken, 'Super Jump (Native Flag)') end

            if GetUsingnightvision(true) and not IsPedUsingNightVision(ped) then TriggerServerEvent('jeler:flag', SecurityToken, 'Forced Night Vision') end
            if GetUsingseethrough(true) and not IsPedUsingSeethrough(ped) then TriggerServerEvent('jeler:flag', SecurityToken, 'Forced Thermal Vision') end

            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsUsing(ped)
                if GetVehicleTopSpeedModifier(veh) > 10.0 then TriggerServerEvent('jeler:flag', SecurityToken, 'Vehicle Speed Mod') end
                if GetVehicleCheatPowerIncrease(veh) > 1.0 then TriggerServerEvent('jeler:flag', SecurityToken, 'Vehicle Power Mod') end
            end

            if NetworkIsInSpectatorMode() then TriggerServerEvent('jeler:flag', SecurityToken, 'Spectate Mode Active') end
        end
    end
end)