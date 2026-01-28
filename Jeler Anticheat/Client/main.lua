local SecurityToken = nil
local initialized = false

-- 1. SOLICITAR TOKEN
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    print("Jeler AC: Requesting Security Token...")
    TriggerServerEvent('jeler:requestToken')
end)

-- 2. RECIBIR TOKEN
RegisterNetEvent('jeler:setToken')
AddEventHandler('jeler:setToken', function(token)
    SecurityToken = token
    initialized = true
    print("Jeler AC: Protected & Running.")
end)

-- 3. HEARTBEAT SEGURO
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(20000)
        if initialized and SecurityToken then
            TriggerServerEvent('jeler:heartbeat', SecurityToken)
        end
    end
end)

-- =============================================================================
-- DETECTOR CLIENTE (CHEATS PRIVADOS)
-- =============================================================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000)
        if initialized and SecurityToken then
            local pid = PlayerId()
            local ped = PlayerPedId()
            
            -- [A] GODMODE & INVISIBILIDAD
            if GetPlayerInvincible(pid) then TriggerServerEvent('jeler:flag', SecurityToken, 'Godmode (Native Flag)') end
            
            -- [B] DAÑO Y ARMAS
            local currentWeapon = GetSelectedPedWeapon(ped)
            if GetPlayerWeaponDamageModifier(pid) > 1.2 then TriggerServerEvent('jeler:flag', SecurityToken, 'Damage Modifier (Player)') end
            if GetWeaponDamageModifier(currentWeapon) > 1.2 then TriggerServerEvent('jeler:flag', SecurityToken, 'Damage Modifier (Weapon)') end

            -- Detección de Balas Explosivas / Fuego (Magic Ammo)
            local damageType = GetWeaponDamageType(currentWeapon)
            -- Grupos que SI pueden ser explosivos (RPG, Granada)
            local weaponGroup = GetWeapontypeGroup(currentWeapon)
            local isExplosiveWeapon = (weaponGroup == 970310034 or weaponGroup == 1159398588) 

            if (damageType == 4 or damageType == 5) and not isExplosiveWeapon then
                TriggerServerEvent('jeler:flag', SecurityToken, 'Explosive/Fire Ammo Detected')
            end
            
            -- [C] MOVIMIENTO
            local speed = GetEntitySpeed(ped)
            if not IsPedInAnyVehicle(ped, false) and not IsPedFalling(ped) and not IsPedRagdoll(ped) then
                if IsPedWalking(ped) and speed > Config.MaxWalkSpeed then
                    TriggerServerEvent('jeler:flag', SecurityToken, 'Speed Walk')
                end
                if (IsPedRunning(ped) or IsPedSprinting(ped)) and speed > Config.MaxSprintSpeed then
                    TriggerServerEvent('jeler:flag', SecurityToken, 'Speed Sprint')
                end
            end

            -- [D] SUPER JUMP
            if IsPedJumping(ped) and GetPlayerSuperJumpEnabled(pid) then 
                TriggerServerEvent('jeler:flag', SecurityToken, 'Super Jump (Native Flag)') 
            end

            -- [E] VISIÓN (THERMAL / NIGHT)
            if GetUsingnightvision(true) and not IsPedUsingNightVision(ped) then
                TriggerServerEvent('jeler:flag', SecurityToken, 'Forced Night Vision')
            end
            if GetUsingseethrough(true) and not IsPedUsingSeethrough(ped) then
                TriggerServerEvent('jeler:flag', SecurityToken, 'Forced Thermal Vision')
            end

            -- [F] VEHICLE CHEATS
            if IsPedInAnyVehicle(ped, false) then
                local veh = GetVehiclePedIsUsing(ped)
                if GetVehicleTopSpeedModifier(veh) > 10.0 then
                    TriggerServerEvent('jeler:flag', SecurityToken, 'Vehicle Speed Mod')
                end
                if GetVehicleCheatPowerIncrease(veh) > 1.0 then
                    TriggerServerEvent('jeler:flag', SecurityToken, 'Vehicle Power Mod')
                end
            end

            -- [G] SPECTATE
            if NetworkIsInSpectatorMode() then
                TriggerServerEvent('jeler:flag', SecurityToken, 'Spectate Mode Active')
            end
        end
    end
end)