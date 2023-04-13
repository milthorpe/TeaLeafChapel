/*
 *		SHARED SOLVER METHODS
 */
module solver_methods {

    // Copies the current u into u0
    proc copy_u (const in x: int, const in y: int, const in halo_depth: int, 
    ref u: [?u_domain] real, ref u0: [u_domain] real){
        
        // whole array assignment instead of individually assigning
        var halo_domain = u_domain[halo_depth..< x - halo_depth, halo_depth..<y-halo_depth];
        u0[halo_domain] = u[halo_domain]; 
    }

    // Calculates the current value of r
    proc calculate_residual(const in x: int, const in y: int, const in halo_depth: int, 
    ref u: [?Domain] real, ref u0: [Domain] real, ref r: [Domain] real, ref kx: [Domain] real,
    ref ky: [Domain] real){

        const inner = Domain[halo_depth..< x - halo_depth, halo_depth..<y-halo_depth];
        forall (i, j) in inner do {
            const smvp: real = (1.0 + (kx[i+1, j]+kx[i, j])
                + (ky[i, j+1]+ky[i, j]))*u[i, j]
                - (kx[i+1, j]*u[i+1, j]+kx[i, j]*u[i-1, j])
                - (ky[i, j+1]*u[i, j+1]+ky[i, j]*u[i, j-1]);
            
            r[i, j] = u0[i, j] - smvp;
        }
    }

    // Calculates the 2 norm of a given buffer
    proc calculate_2norm (const in x: int, const in y: int, const in halo_depth: int, 
    ref buffer: [?buffer_domain] real, ref norm: real){
        var norm_temp: real;
        const inner = buffer_domain[halo_depth..< x - halo_depth, halo_depth..<y-halo_depth];
        
        forall (i, j) in inner with (+ reduce norm_temp) do {
            norm_temp += buffer[i, j]*buffer[i, j];	
        }
        
        norm += norm_temp;
    }

    // Finalises the solution
    proc finalise (const in x: int, const in y: int, const in halo_depth: int, 
    ref energy: [?Domain] real, ref density: [Domain] real, ref u: [Domain] real) {

        var halo_domain = Domain[halo_depth..< x - halo_depth, halo_depth..<y-halo_depth];
        energy[halo_domain] = u[halo_domain] / density[halo_domain];
    }
}