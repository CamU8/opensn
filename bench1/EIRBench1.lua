-- Check num_procs
num_procs = 4
if check_num_procs == nil and number_of_processes ~= num_procs then
  Log(
    LOG_0ERROR,
    "Incorrect amount of processors. "
      .. "Expected "
      .. tostring(num_procs)
      .. ". Pass check_num_procs=false to override if possible."
  )
  os.exit(false)
end

-- test
-- Setup the mesh
nodesX = {}
nodesY = {}
n_cells = 1
w1 = 1.5
w2 = 6.4
w3 = 1
h1 = 1
h2 = 6.4
h3 = 1.5
minX = 0
minY = 0
dx1 = w1 / n_cells
dx2 = w2 / n_cells
dx3 = w3 / n_cells
dy1 = h1 / n_cells
dy2 = h2 / n_cells
dy3 = h3 / n_cells
for i = 1, (n_cells + 1) do
  k = i - 1
  nodesX[i] = minX + k * dx1
  nodesX[i + n_cells] = minX + w1 + k * dx2
  nodesX[i + 2 * n_cells] = minX + w1 + w2 + k * dx3
  nodesY[i] = minY + k * dy1
  nodesY[i + n_cells] = minY + h1 + k * dy2
  nodesY[i + 2 * n_cells] = minY + h1 + h2 + k * dy3
end

midX = (w1 + w2 + w3 - minX) / 2
midY = (h1 + h2 + h3 - minY) / 2

meshgen = mesh.OrthogonalMeshGenerator.Create({
  node_sets = { nodesX, nodesY }
})
mesh.MeshGenerator.Execute(meshgen)

-- Set Material IDs
vol0 = logvol.RPPLogicalVolume.Create({ xmin = 0., xmax = 8.9, ymin = 0., ymax = 8.9, infz = true })
vol1 = logvol.RPPLogicalVolume.Create({ xmin = 1.5, xmax = 7.9, ymin = 1., ymax = 7.4, infz = true })
mesh.SetMaterialIDFromLogicalVolume(vol1, 1)
vol2 = logvol.BooleanLogicalVolume.Create({
  parts = {{op = true, lv = vol0}, {op = false, lv= vol1}}
})
mesh.SetMaterialIDFromLogicalVolume(vol2, 0)
vol = {vol0, vol2}

-- Add Materials
materials = {}
materials[1] = mat.AddMaterial("Water")
materials[2] = mat.AddMaterial("Fuel")
mat.SetProperty(materials[1], TRANSPORT_XSECTIONS, OPENSN_XSFILE, 'Water.xs')
mat.SetProperty(materials[2], TRANSPORT_XSECTIONS, OPENSN_XSFILE, 'Fuel.xs')

-- Set up physics
num_g, num_m = 2, 0
pquad = aquad.CreateProductQuadrature(GAUSS_LEGENDRE_CHEBYSHEV, 1, 1)
aquad.OptimizeForPolarSymmetry(pquad, 4.0 * math.pi)

num_groups = 2
lbs_block = {
  num_groups = 2,
  groupsets = {
    {
      groups_from_to = { 0, num_groups - 1 },
      angular_quadrature_handle = pquad,
      inner_linear_method = "gmres",
      l_max_its = 50,
      gmres_restart_interval = 50,
      l_abs_tol = 1.0e-10,
      groupset_num_subsets = num_g,
    },
  },
}

lbs_options = {
  boundary_conditions = {
    { name = "xmin", type = "reflecting" },
    { name = "ymin", type = "reflecting" },
    { name = "xmax", type = "reflecting" },
    { name = "ymax", type = "reflecting" }
  },
  scattering_order = num_m,

  use_precursors = false,

  verbose_inner_iterations = false,
  verbose_outer_iterations = true,
}

phys1 = lbs.DiscreteOrdinatesSolver.Create(lbs_block)
lbs.SetOptions(phys1, lbs_options)

k_solver0 = lbs.PowerIterationKEigen.Create({ lbs_solver_handle = phys1 })
solver.Initialize(k_solver0)
solver.Execute(k_solver0)

fflist, count = lbs.GetScalarFieldFunctionList(phys1)
for n = 1, 2 do
  for g = 1, num_g do
    ffi1 = fieldfunc.FFInterpolationCreate(VOLUME)
    curffi = ffi1
    fieldfunc.SetProperty(curffi, OPERATION, OP_AVG)
    fieldfunc.SetProperty(curffi, LOGICAL_VOLUME, vol[n])
    fieldfunc.SetProperty(curffi, ADD_FIELDFUNCTION, fflist[g])
    fieldfunc.Initialize(curffi)
    fieldfunc.Execute(curffi)
    phi_avg = fieldfunc.GetValue(curffi)
    if n == 1 and g == 1 then
      norm_c = phi_avg
    end
    log.Log(LOG_0, string.format("Avg Flux for region: %i, group: %i is %.5e",n, g, phi_avg/norm_c))
  end
end

vtk_basename = "EIR"
fieldfunc.ExportToVTK(fflist[1], vtk_basename)

-- Exporting the mesh
mesh.ExportToPVTU("EIRBenchmark1")