



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

midX = (w1 + w2 + w3 - xmin) / 2
midY = (h1 + hw + h3 - ymin) / 2

meshgen = mesh.OrthogonalMeshGenerator.Create({
  node_sets = { nodesX, nodesY },
  partitioner = mesh.KBAGraphPartitioner.Create({
    nx = 2,
    ny = 2,
    xcuts = { midX },
    ycuts = { midY },
  }),
})

mesh.MeshGenerator.Execute(meshgen)

mesh.SetUniformMaterialID(1)
vol0 = logvol.RPPLogicalVolume.Create({ xmin = minX + w1 , xmax = minX + w1 + w2 , ymin = minY + h1 , ymax = minY + h1 + h2 , infz = true })
mesh.SetMaterialIDFromLogicalVolume(vol0, 0)

materials = {}
materials[1] = mat.AddMaterial("Fuel")
materials[2] = mat.AddMaterial("Water")

mat.SetProperty(materials[1], TRANSPORT_XSECTIONS, OPENSN_XSFILE, "Fuel.xs")
mat.SetProperty(materials[2], TRANSPORT_XSECTIONS, OPENSN_XSFILE, "Water.xs")

num_groups = 2
src1 = { 1 , 0 }
src2 = { 0 , 0 }

mat.SetProperty(materials[1], ISOTROPIC_MG_SOURCE, FROM_ARRAY, src1)
mat.SetProperty(materials[2], ISOTROPIC_MG_SOURCE, FROM_ARRAY, src2)

nazimu = 1
npolar = 2
pquad = aquad.CreateProductQuadrature(GAUSS_LEGENDRE_CHEBYSHEV, nazimu, npolar)
aquad.OptimizeForPolarSymmetry(pquad, 4.0 * math.pi)

lbs_block = {
  num_groups = num_groups,
  groupsets = {
    {
      groups_from_to = { 0, 1 },
      angular_quadrature_handle = pquad,
      angle_aggregation_num_subsets = 1,
      inner_linear_method = "gmres",
      l_abs_tol = 1.0e-6,
      l_max_its = 300,
      gmres_restart_interval = 30,
    },
  },
  options = {
    scattering_order = 0,
    boundary_conditions = {
      { name = "xmin", type = "reflecting" },
      { name = "xmax", type = "reflecting" },
      { name = "ymin", type = "reflecting" },
      { name = "ymax", type = "reflecting" },
    },
  },
}

phys1 = lbs.DiscreteOrdinatesSolver.Create(lbs_block)

k_solver0 = lbs.PowerIterationKEigen.Create({ lbs_solver_handle = phys1 })
solver.Initialize(k_solver0)
solver.Execute(k_solver0)

fflist, count = lbs.GetScalarFieldFunctionList(phys1)