-- Example Rust MUD Client Lua hooks.
--
-- Editor support:
-- - `scripts/mud-client-api.lua` contains LuaLS/EmmyLua annotations for `client`
--   and hook context tables.
-- - `.luarc.json` points LuaLS at this folder so completions work in editors
--   that support Lua Language Server.

function wield_primary(_)
    local has_shield = client.var.get("has_shield")
    if has_shield == "false" then
        client.send("wear shield")
        client.var.set("has_shield", "true")
    end

    local primary_weapon = client.var.get("primary")

    client.send("wield " .. primary_weapon)
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
