-- Example Rust MUD Client Lua hooks.
--
-- Editor support:
-- - `scripts/mud-client-api.lua` contains LuaLS/EmmyLua annotations for `client`
--   and hook context tables.
-- - `.luarc.json` points LuaLS at this folder so completions work in editors
--   that support Lua Language Server.

function wield_primary(_)
    local primary_weapon = client.var.get("primary")

    client.send("wield " .. primary_weapon)

    local has_shield = client.var.get("has_shield")
    if has_shield == "false" then
        client.send("wear shield")
        client.var.set("has_shield", "true")
    end
end

function wield_hitter(_)
    local has_shield = client.var.get("has_shield")
    if has_shield == "true" then
        client.send("remove shield")
        client.var.set("has_shield", "false")
    end

    local hitter_weapon = client.var.get("hitter")
    client.send("wield " .. hitter_weapon)
end

function weapon_list(_)
    local primary_weapon = client.var.get("primary")
    local secondary_weapon = client.var.get("secondary")
    local hitter_weapon = client.var.get("hitter")

    local lines = {
        "# Weapon List",
        "",
        "| Weapon Type | Weapon Name |",
        "| ---: | --- |",
        "| Primary | " .. primary_weapon .. " |",
        "| Secondary | " .. secondary_weapon .. " |",
        "| Hitter | " .. hitter_weapon .. " |",
        "",
        "**Note**: See aliases wp and wt for switching weapons."
    }

    client.echo(table.concat(lines, "\n"), { markdown = true })
end
