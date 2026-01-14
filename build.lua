local build = {}

function build.install_dependencies()
    print("Installing Lua dependencies...")
    -- Install LuaSocket
    os.execute("luarocks install luasocket")
    -- Install other deps
    os.execute("luarocks install json")
    print("Dependencies installed")
end

function build.compile()
    print("Compiling Lua code...")
    -- Dummy compilation - just check syntax
    local files = {
        "dragonslayer/core/orchestrator.lua",
        "dragonslayer/fuzzing/base_fuzzer.lua",
        "lua_jit_compiler/compiler.lua"
    }

    for _, file in ipairs(files) do
        local chunk, err = loadfile(file)
        if chunk then
            print("✓ " .. file .. " compiled successfully")
        else
            print("✗ " .. file .. " failed: " .. err)
        end
    end
    print("Compilation complete")
end

function build.test()
    print("Running tests...")
    local success = pcall(function()
        dofile("validate_fuzzer.lua")
    end)
    if success then
        print("Tests passed")
    else
        print("Tests failed")
    end
end

function build.package()
    print("Creating package...")
    -- Create a simple package
    os.execute("mkdir -p dist")
    os.execute("cp -r dragonslayer dist/")
    os.execute("cp -r lua_jit_compiler dist/")
    os.execute("cp *.lua dist/")
    print("Package created in dist/")
end

function build.clean()
    print("Cleaning build artifacts...")
    os.execute("rm -rf dist/")
    print("Clean complete")
end

-- Main build function
function build.run(target)
    target = target or "all"

    if target == "deps" or target == "all" then
        build.install_dependencies()
    end

    if target == "compile" or target == "all" then
        build.compile()
    end

    if target == "test" or target == "all" then
        build.test()
    end

    if target == "package" or target == "all" then
        build.package()
    end

    print("Build " .. target .. " completed")
end

return build