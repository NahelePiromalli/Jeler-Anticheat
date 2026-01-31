print("^2>>> JELER AC: CLIENTE CARGADO EXITOSAMENTE (v9.0 - FULL TEST MODE) <<<")

local SecurityToken = nil
local CurrentSeq = 0 
local initialized = false

-- ESTADO DE CARGA
local HasSpawned = false 
local ProtectionTimer = 0

-- CONTADOR DE PERSISTENCIA (ENFORCER ANTI-LAG)
local GodmodeForceCounter = 0

-- 1. SOLICITAR TOKEN AL INICIAR
Citizen.CreateThread(function()
    Citizen.Wait(2000) 
    print("Jeler AC: Requesting Security Token...")
    TriggerServerEvent('jeler:requestToken')
end)

-- [FIX REINICIO] EVITA DETECCIONES AL HACER 'ENSURE'
Citizen.CreateThread(function()
    Citizen.Wait(1000)
    if NetworkIsPlayerActive(PlayerId()) then
        HasSpawned = true
        ProtectionTimer = GetGameTimer() + 10000 -- 10 segundos de gracia tras reiniciar
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

-- SPAWN DETECT (PROTECCIÓN DE PANTALLA DE CARGA NORMAL)
AddEventHandler('playerSpawned', function()
    HasSpawned = true
    ProtectionTimer = GetGameTimer() + 20000 -- 20s de gracia al nacer
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

-- 4. ESCANER DE GLOBALES (DETECTAR INYECTORES LUA)
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

-- 5. DETECTORES DE TECLAS PROHIBIDAS
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

-- 6. LOOP PRINCIPAL (INTERNAL CHEATS: GODMODE NATIVO Y SPEEDHACK)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- Revisar cada 1 segundo
        if initialized and SecurityToken then
            
            if HasSpawned then
                local pid = PlayerId()
                local ped = PlayerPedId()

                if NetworkIsPlayerActive(pid) and not IsPlayerDead(ped) and not IsPlayerSwitchInProgress() then
                    
                    -- [GODMODE CHECK - LOGICA INTERNAL]
                    if GetPlayerInvincible(pid) then
                        if GetGameTimer() > ProtectionTimer then
                            -- Intentar apagar el godmode
                            SetPlayerInvincible(pid, false)
                            SetEntityInvincible(ped, false)
                            
                            GodmodeForceCounter = GodmodeForceCounter + 1
                            
                            -- Si persiste por 10 segundos, es un cheat bloqueado
                            if GodmodeForceCounter >= 10 then
                                TriggerServerEvent('jeler:flag', SecurityToken, 'Godmode (Persistent/Cheat Locked)')
                                GodmodeForceCounter = 0 
                            end
                        end
                    else
                        if GodmodeForceCounter > 0 then GodmodeForceCounter = 0 end
                    end
                end
                
                -- CHEQUEOS DE COMBATE Y MOVIMIENTO DE SUELO
                if GetGameTimer() > ProtectionTimer then
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

-- =====================================================
-- 7. DETECTOR ANTI-EXTERNAL (GODMODE DE MEMORIA)
-- =====================================================
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) 
        if initialized and SecurityToken and HasSpawned then
            local ped = PlayerPedId()
            if not IsPlayerDead(ped) and GetGameTimer() > ProtectionTimer then
                if GetEntityHealth(ped) >= (GetEntityMaxHealth(ped) - 2) then
                    if HasEntityBeenDamagedByAnyPed(ped) or HasEntityBeenDamagedByAnyVehicle(ped) or HasEntityBeenDamagedByAnyObject(ped) then
                        TriggerServerEvent('jeler:flag', SecurityToken, 'External Godmode (Health Lock Detected)')
                        ClearEntityLastDamageEntity(ped)
                    end
                end
            end
        end
    end
end)

-- =====================================================
-- 8. DETECTOR DE NOCLIP MEJORADO (POSICIÓN vs VELOCIDAD)
-- =====================================================
local lastCoords = nil -- Variable para guardar posición anterior

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(500) -- Analizamos cada medio segundo
        if initialized and SecurityToken and HasSpawned then
            local ped = PlayerPedId()
            
            -- Si el jugador está vivo y ya pasó la protección de spawn
            if not IsPlayerDead(ped) and GetGameTimer() > ProtectionTimer then
                
                local currentCoords = GetEntityCoords(ped)
                
                -- Solo analizamos si tenemos una posición anterior guardada
                if lastCoords then
                    -- Calculamos distancia real recorrida en 0.5 segundos
                    local dist = #(currentCoords - lastCoords)
                    
                    -- Si se movió más de 4 metros en medio segundo (aprox 30km/h)
                    if dist > 4.0 then
                        
                        -- Verificamos si está en el aire
                        local height = GetEntityHeightAboveGround(ped)
                        
                        -- CONDICIONES DE CASTIGO:
                        -- 1. No está en vehículo
                        -- 2. Está alto (más de 3m del suelo)
                        -- 3. No está cayendo (paracaídas o caída libre)
                        -- 4. No está nadando
                        if not IsPedInAnyVehicle(ped, false) and height > 3.0 then
                            if not IsPedFalling(ped) and not IsPedInParachuteFreeFall(ped) and not IsPedSwimming(ped) then
                                
                                -- ALERTA: Se movió rápido en el aire sin vehículo ni gravedad
                                TriggerServerEvent('jeler:flag', SecurityToken, 'Noclip Detected (Air Movement)')
                                
                                -- Opcional: Teletransportarlo al suelo para anular el cheat
                                -- local groundZ = GetHeightmapBottomZForPosition(currentCoords.x, currentCoords.y)
                                -- SetEntityCoords(ped, currentCoords.x, currentCoords.y, groundZ)
                            end
                        end
                    end
                end
                
                -- Guardamos la posición actual para la próxima comparación
                lastCoords = currentCoords
            else
                lastCoords = nil
            end
        end
    end
end)

-- =====================================================
-- 9. [NUEVO] GESTOR DE PANTALLA (NUI HANDLER)
-- ESTO HACE QUE SE VEA EL HTML
-- =====================================================
RegisterNetEvent('jeler:mostrarPantalla')
AddEventHandler('jeler:mostrarPantalla', function(reason)
    print("^2[CLIENTE] Recibida orden de mostrar pantalla por: " .. reason .. "^7")
    
    -- Activar mouse para poder cerrar
    SetNuiFocus(true, true)

    -- Enviar info al index.html
    SendNUIMessage({
        action = "open",
        reason = reason,
        banId = "TEST-BAN-" .. math.random(1000,9999)
    })
end)

RegisterNUICallback('close', function(data, cb)
    SetNuiFocus(false, false)
    cb('ok')
end)


-- =====================================================
-- ZONA DE PRUEBAS Y COMANDOS
-- =====================================================

-- COMANDO 1: VER PANTALLA (Sin hacks)
RegisterCommand("testac", function()
    if initialized and SecurityToken then
        print("^3[TEST] Enviando alerta manual...^7")
        TriggerServerEvent('jeler:flag', SecurityToken, 'TEST MANUAL DE PANTALLA')
    else
        print("El AC aun no inicia.")
    end
end)

-- COMANDO 2: SIMULAR HACK INTERNO
RegisterCommand("hack_godmode", function()
    print("^1[TEST] ^7!!! ACTIVANDO GODMODE INTERNO (Native) !!!")
    local ped = PlayerPedId()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0) 
            SetEntityInvincible(ped, true) 
        end
    end)
end)

-- COMANDO 3: SIMULAR HACK EXTERNO
RegisterCommand("simular_external", function()
    print("^1[TEST] ^7!!! SIMULANDO GODMODE EXTERNO (Health Lock) !!!")
    local ped = PlayerPedId()
    Citizen.CreateThread(function()
        while true do
            Citizen.Wait(0) 
            if GetEntityHealth(ped) < 200 then SetEntityHealth(ped, 200) end
        end
    end)
end)

-- COMANDO 4: SIMULAR NOCLIP
RegisterCommand("test_noclip", function()
    print("^3[TEST] ^7Simulando Noclip (Vuelo rápido)...")
    local ped = PlayerPedId()
    Citizen.CreateThread(function()
        -- Teletransportamos al jugador hacia adelante en el aire
        for i=1, 20 do
            local forward = GetEntityForwardVector(ped)
            local newPos = GetEntityCoords(ped) + (forward * 2.0) + vector3(0,0,0.5) -- Avanza y sube
            SetEntityCoords(ped, newPos.x, newPos.y, newPos.z, false, false, false, false)
            Citizen.Wait(50)
        end
    end)
end)

-- COMANDO 5: NOCLIP MANUAL (PARA PROBAR LIBREMENTE)
local noclipActive = false
RegisterCommand("live_noclip", function()
    noclipActive = not noclipActive
    local ped = PlayerPedId()

    if noclipActive then
        print("^2[TEST] Noclip Manual ACTIVADO. Usa W/A/S/D/Shift/Ctrl para volar.^7")
        SetEntityInvincible(ped, true)
        SetEntityVisible(ped, false, false)
    else
        print("^1[TEST] Noclip Manual DESACTIVADO.^7")
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true, false)
        FreezeEntityPosition(ped, false)
        return
    end

    Citizen.CreateThread(function()
        local currentVelocity = vector3(0,0,0)
        local speed = 1.0 -- Velocidad base
        
        while noclipActive do
            Citizen.Wait(0)
            local ped = PlayerPedId()
            FreezeEntityPosition(ped, true) -- Congelamos física para simular Noclip real
            
            -- Obtener dirección de la cámara
            local camRot = GetGameplayCamRot(2)
            local forward, right, up, pPos = GetEntityMatrix(ped)
            
            -- Calcular dirección basada en cámara (Truco matemático simple)
            local radRot = vector3(math.rad(camRot.x), math.rad(camRot.y), math.rad(camRot.z))
            local forwardDir = vector3(-math.sin(radRot.z) * math.abs(math.cos(radRot.x)), math.cos(radRot.z) * math.abs(math.cos(radRot.x)), math.sin(radRot.x))
            local rightDir = vector3(math.cos(radRot.z), math.sin(radRot.z), 0)
            
            -- Controles
            local newPos = GetEntityCoords(ped)
            local moved = false
            
            -- Shift para correr más rápido
            local multiplier = 1.0
            if IsControlPressed(0, 21) then multiplier = 4.0 end 

            -- W (Adelante)
            if IsControlPressed(0, 32) then 
                newPos = newPos + (forwardDir * speed * multiplier * 0.5)
                moved = true
            end
            -- S (Atrás)
            if IsControlPressed(0, 33) then 
                newPos = newPos - (forwardDir * speed * multiplier * 0.5)
                moved = true
            end
            -- A (Izquierda)
            if IsControlPressed(0, 34) then 
                newPos = newPos - (rightDir * speed * multiplier * 0.5) 
                moved = true
            end
            -- D (Derecha)
            if IsControlPressed(0, 35) then 
                newPos = newPos + (rightDir * speed * multiplier * 0.5) 
                moved = true
            end
            
            -- Espacio/Shift (Subir) y Ctrl (Bajar) simples
            if IsDisabledControlPressed(0, 22) then newPos = newPos + vector3(0,0, speed * multiplier * 0.5); moved = true end
            if IsDisabledControlPressed(0, 36) then newPos = newPos - vector3(0,0, speed * multiplier * 0.5); moved = true end

            -- Aplicar movimiento (Teletransportar)
            if moved then
                SetEntityCoordsNoOffset(ped, newPos.x, newPos.y, newPos.z, true, true, true)
                
                -- Girar personaje hacia donde mira la cámara
                SetEntityHeading(ped, camRot.z)
            end
        end
    end)
end)


-- COMANDO 6: SIMULADOR DE CRASH (SPAWN MASIVO)
RegisterCommand("test_crash", function()
    print("^1[TEST] ^7!!! INTENTANDO CRASHEAR/SPAWNEAR 50 OBJETOS !!!")
    
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local model = GetHashKey("prop_barrier_work06a") -- Un objeto común
    
    RequestModel(model)
    while not HasModelLoaded(model) do Citizen.Wait(0) end

    -- Intentamos spawnear 50 objetos en un bucle rapidísimo
    Citizen.CreateThread(function()
        for i=1, 50 do
            -- Esto enviará 50 peticiones al servidor en milisegundos
            local obj = CreateObject(model, coords.x + math.random(-5,5), coords.y + math.random(-5,5), coords.z, true, true, false)
            Citizen.Wait(10) -- Muy rápido
        end
        print("^2[TEST] ^7Ataque finalizado. Revisa si salió la pantalla de bloqueo.")
    end)
end)