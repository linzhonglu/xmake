--!A cross-platform build utility based on Lua
--
-- Licensed to the Apache Software Foundation (ASF) under one
-- or more contributor license agreements.  See the NOTICE file
-- distributed with this work for additional information
-- regarding copyright ownership.  The ASF licenses this file
-- to you under the Apache License, Version 2.0 (the
-- "License"); you may not use this file except in compliance
-- with the License.  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
-- 
-- Copyright (C) 2015 - 2017, TBOOX Open Source Group.
--
-- @author      ruki
-- @file        build.lua
--

-- imports
import("core.base.option")
import("core.project.config")
import("core.sandbox.sandbox")

-- build for xmake file
function _build_for_xmakefile(package, buildfile)

    -- configure it first
    os.vrun("xmake f -p $(plat) -a $(arch) -m $(mode) -c")

    -- build it
    os.vrun("xmake")
end

-- build for makefile
function _build_for_makefile(package, buildfile)

    -- only for host platform now
    assert(os.host() == config.plat() and os.arch() == config.arch())

    -- build it
    os.vrun("make")
end

-- build for configure
function _build_for_configure(package, buildfile)

    -- only for host platform now
    assert(os.host() == config.plat() and os.arch() == config.arch())

    -- make prefix directory
    os.mkdir(".prefix")

    -- configure it first
    os.vrun("./configure --prefix=%s", path.absolute(".prefix"))

    -- build it
    os.vrun("make")

    -- install to .prefix
    os.vrun("make install")
end

-- build for cmakelist
function _build_for_cmakelists(package, buildfile)

    -- only for host platform now
    assert(os.host() == config.plat() and os.arch() == config.arch())

    -- make makefile first
    --
    -- @note it will only attempt to build, so we need install cmake manually first if we want to build it successfully
    --
    os.vrun("cmake -DCMAKE_INSTALL_PREFIX=%s .", path.absolute(".prefix"))

    -- build it
    os.vrun("make")

    -- install to .prefix
    os.vrun("make install")
end

-- build for *.sln
function _build_for_sln(package, buildfile)

    -- only for host platform now
    assert(os.host() == config.plat())

    -- TODO handle arch and mode
    -- build it for windows
    if config.plat() == "windows" then
        os.vrun("msbuild %s -nologo -t:Rebuild -p:Configuration=Release", buildfile)
        return 
    end

    -- continue to attempt to build using other tools
    raise()
end

-- on build the given package
function _on_build_package(package)

    -- TODO *.vcproj, premake.lua, scons, autogen.sh, Makefile.am, ...
    -- init build scripts
    local buildscripts =
    {
        {"xmake.lua",       _build_for_xmakefile    }
    ,   {"*.sln",           _build_for_sln          }
    ,   {"CMakeLists.txt",  _build_for_cmakelists   }
    ,   {"configure",       _build_for_configure    }
    ,   {"[mM]akefile",     _build_for_makefile     }
    }

    -- attempt to build it
    for _, buildscript in pairs(buildscripts) do

        -- save the current directory 
        local oldir = os.curdir()

        -- try building 
        local ok = try
        {
            function ()

                -- attempt to build it if file exists
                local files = os.files(buildscript[1])
                if #files > 0 then
                    buildscript[2](package, files[1])
                    return true
                end
            end,

            catch
            {
                function (errors)

                    -- trace verbose info
                    if errors then
                        vprint(errors)
                    end
                end
            }
        }

        -- restore directory
        os.cd(oldir)

        -- ok?
        if ok then return end
    end

    -- failed
    raise("attempt to build package %s failed!", package:fullname())
end

-- run script
function _run_script(script, package)

    -- TODO
    -- register filter handler before building
--    sandbox.filter_register(script, "package.build", function (var) 
--    end)

    -- run it
    script(package)

    -- cancel filter handler before building
--    sandbox.filter_register(script, "package.build", nil)
end

-- build the given package
function main(package)

    -- the package scripts
    local scripts =
    {
        package:script("build_before") 
    ,   package:script("build", _on_build_package)
    ,   package:script("build_after") 
    }

    -- save the current directory
    local oldir = os.curdir()

    -- build it
    for i = 1, 3 do
        local script = scripts[i]
        if script ~= nil then
            _run_script(script, package)
        end
    end

    -- restore the current directory
    os.cd(oldir)
end
