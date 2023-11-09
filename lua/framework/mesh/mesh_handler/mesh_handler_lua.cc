#include "framework/lua.h"

#include "framework/mesh/mesh_handler/mesh_handler.h"
#include "framework/runtime.h"

#include "framework/logging/log.h"

#include <iostream>
#include "mesh_handler_lua.h"
#include "framework/console/console.h"

RegisterLuaFunctionAsIs(chiMeshHandlerCreate);
RegisterLuaFunctionAsIs(chiMeshHandlerSetCurrent);
RegisterLuaFunctionAsIs(chiMeshHandlerExportMeshToObj);
RegisterLuaFunctionAsIs(chiMeshHandlerExportMeshToVTK);
RegisterLuaFunctionAsIs(chiMeshHandlerExportMeshToExodus);

int
chiMeshHandlerCreate(lua_State* L)
{
  int index = (int)chi_mesh::PushNewHandlerAndGetIndex();
  lua_pushnumber(L, index);

  Chi::log.LogAllVerbose2() << "chiMeshHandlerCreate: Mesh Handler " << index << " created\n";

  return 1;
}

int
chiMeshHandlerSetCurrent(lua_State* L)
{
  int num_args = lua_gettop(L);
  if (num_args != 1) LuaPostArgAmountError("chiMeshHandlerSetCurrent", 1, num_args);

  int handle = lua_tonumber(L, 1);

  if ((handle < 0) or (handle >= Chi::meshhandler_stack.size()))
  {
    Chi::log.LogAllError() << "Invalid handle to mesh handler specified "
                           << "in call to chiMeshHandlerSetCurrent";
    Chi::Exit(EXIT_FAILURE);
  }

  Chi::current_mesh_handler = handle;

  Chi::log.LogAllVerbose2() << "chiMeshHandlerSetCurrent: set to " << handle;

  return 0;
}