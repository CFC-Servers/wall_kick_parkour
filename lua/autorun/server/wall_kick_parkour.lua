local traceDistance = 35
local softSounds = {
    "physics/body/body_medium_impact_soft2.wav",
    "physics/body/body_medium_impact_soft3.wav",
    "physics/body/body_medium_impact_soft4.wav",
    "physics/cardboard/cardboard_box_impact_soft1.wav",
    "physics/cardboard/cardboard_box_impact_soft2.wav",
    "physics/cardboard/cardboard_box_impact_soft3.wav",
    "physics/cardboard/cardboard_box_impact_soft4.wav",
}

local footstepSounds = {
    "physics/wood/wood_box_footstep1.wav",
    "physics/wood/wood_box_footstep2.wav",
    "physics/wood/wood_box_footstep3.wav",
    "physics/wood/wood_box_footstep4.wav",
}

local wallkickEnabled = CreateConVar( "wallkick_enabled", 1, FCVAR_ARCHIVE ):GetBool()
cvars.AddChangeCallback( "wallkick_enabled", function( _, _, newValue )
    wallkickEnabled = tobool( newValue )
end, "WallKickEnabledCallback" )

local wallkickForceVertical = CreateConVar( "wallkick_force_vertical", 300, FCVAR_ARCHIVE, "How high each wall kick pushes the player" ):GetInt()
cvars.AddChangeCallback( "wallkick_force_vertical", function( _, _, newValue )
    wallkickForceVertical = tonumber( newValue )
end, "WallKickForceVerticalCallback" )

local wallkickForceHorizontal = CreateConVar( "wallkick_force_horizontal", 150, FCVAR_ARCHIVE, "How far sideways each wall kick pushes the player" ):GetInt()
cvars.AddChangeCallback( "wallkick_force_horizontal", function( _, _, newValue )
    wallkickForceHorizontal = tonumber( newValue )
end, "WallKickForceHorizontalCallback" )

local wallkickInverted = CreateConVar( "wallkick_inverted", 0, FCVAR_ARCHIVE, "Swaps the left and right keys" ):GetBool()
cvars.AddChangeCallback( "wallkick_inverted", function( _, _, newValue )
    wallkickInverted = tobool( newValue )
end, "WallKickInvertedCallback" )

hook.Add( "KeyPress", "WallKickKeyPress", function( ply, key )
    if key ~= IN_JUMP then return end
    if not wallkickEnabled then return end

    local kickHeight = wallkickForceVertical or 250
    local kickDistance = wallkickForceHorizontal or 150

    if ply:IsOnGround() or ply.WallKickJumpedAlready then return end

    -- By default our direction of jump is 0 which will make it easy to check later if it has changed
    local dir = 0

    -- Disregard this whole thing if the player is holding both left and right
    if ( ply:KeyDown( IN_MOVELEFT ) and ply:KeyDown( IN_MOVERIGHT ) ) then return end
    if ply:InVehicle() then return end
    if ply:GetMoveType() == MOVETYPE_NOCLIP then return end

    -- This determines which direction the player is trying to jump and sets dir accordingly
    if ply:KeyDown( IN_MOVELEFT ) then
        dir = 1
    elseif ply:KeyDown( IN_MOVERIGHT ) then
        dir = -1
    end

    -- Due to overwhelming popular demand
    if wallkickInverted then
        dir = -dir
    end

    -- If we're trying to go left or right
    if dir ~= 0 then

        -- Perform several traces to make it less likely that a hole in geometry would prevent a kick off
        local traceCount = 5
        local accumulatedNormal = Vector( 0, 0, 0 )
        local hit = false
        local hitCount = 0
        for i = 0, ( traceCount - 1 ) do

            -- Our traces are from the bottom of the player to partway up their full height
            local traceStartPos = ply:GetPos() + Vector( 0, 0, ply:OBBMaxs().z * ( 1/4 * i ) )

            local tr = util.TraceLine( {
                start = traceStartPos,
                endpos = traceStartPos + ( ply:GetRight() * traceDistance * dir ),
                filter = ply,
            } )


            if tr.Hit then
                hit = true
                accumulatedNormal = accumulatedNormal + tr.HitNormal
                hitCount = hitCount + 1
            end

        end

        -- Average all of the trace hits
        local normal = accumulatedNormal / hitCount

        -- If that trace hit something, we can start the process of kicking off
        if hit then

            -- Round the normal to coarser increments to make sure we count very similar surfaces and avoid floating point imprecision
            local roundTo = 10
            local x = ( math.Round( ( normal.x * 100 ) / roundTo, 0 ) * roundTo ) / 100
            local y = ( math.Round( ( normal.y * 100 ) / roundTo, 0 ) * roundTo ) / 100
            local z = ( math.Round( ( normal.z * 100 ) / roundTo, 0 ) * roundTo ) / 100
            local roundedNormal = Vector( x, y, z )

            local kHeight = kickHeight or 275

            if ( not ply.LastNormal or ply.LastNormal ~= roundedNormal ) then
                local rightVel = ply:GetRight() * ply:WorldToLocal( ply:GetVelocity() + ply:GetPos() ).y
                local upVel = Vector( 0, 0, kHeight )
                if ply:GetVelocity().z > kHeight then
                    upVel = Vector( 0, 0, ply:GetVelocity().z - kHeight )
                end

                ply:ViewPunch( Angle( 0, 0, 3 * -dir ) )

                local totalVel = rightVel + upVel + Vector( normal.x * kickDistance, normal.y * kickDistance, 0 )

                ply:SetVelocity( totalVel )

                local footstep = footstepSounds[math.random( 1, #footstepSounds )]
                ply:EmitSound( footstep, 100, 100, 0.25 )

                local snd = softSounds[math.random( 1, #softSounds )]
                ply:EmitSound( snd )

            end

            ply.LastNormal = roundedNormal
        end
    end
end )

hook.Add( "OnPlayerHitGround", "WallKickHitGround", function( ply )
    local plyTbl = ply:GetTable()
    plyTbl.WallKickJumpedAlready = nil
    plyTbl.LastNormal = nil
end )
