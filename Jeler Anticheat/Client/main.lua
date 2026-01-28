local initialized = false
Citizen.CreateThread(function()
    Citizen.Wait(2000)
    initialized = true
    print("Sentinel AC Client: Running")
    
    while true do
        TriggerServerEvent('jeler:heartbeat')
        Citizen.Wait(20000)
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(3000)
        if initialized then
            local pid = PlayerId()
            -- Godmode Nativo
            if GetPlayerInvincible(pid) and not IsEntityDead(PlayerPedId()) then
                TriggerServerEvent('jeler:flag', 'Godmode (Native)')
            end
            -- Daño Modificado
            if GetPlayerWeaponDamageModifier(pid) > 1.2 then
                TriggerServerEvent('jeler:flag', 'Damage Modifier')
            end
        end
    end
end)