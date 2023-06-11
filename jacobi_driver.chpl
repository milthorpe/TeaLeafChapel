module jacobi_driver {
    use chunks;
    use settings;
    use local_halos;
    use solver_methods;
    use jacobi;

    // Performs a full solve with the Jacobi solver kernels
    proc jacobi_driver (ref chunk_var : [0..<setting_var.num_chunks] chunks.Chunk, ref setting_var : settings.setting, ref rx: real,
    ref ry: real, ref err: real){

        var Domain = {0..<chunk_var[0].y, 0..<chunk_var[0].x};
        jacobi_init_driver(chunk_var, setting_var, rx, ry, Domain);
        // Iterate until convergence
        var tt_prime : int;
        
        for tt in 0..<setting_var.max_iters do {
            
            jacobi_main_step_driver(chunk_var, setting_var, tt, err, Domain);

            halo_update_driver(chunk_var, setting_var, 1);
            if(abs(err) < setting_var.eps) then break;
            tt_prime += 1;
        }
        writeln("Jacobi iterations : ", tt_prime);
    }

    // Invokes the CG initialisation kernels
    proc jacobi_init_driver (ref chunk_var : [0..<setting_var.num_chunks] chunks.Chunk, ref setting_var : settings.setting, const in rx: real,
    const in ry: real, const in Domain : domain(2)){

        jacobi_init(chunk_var[0].x, chunk_var[0].y, setting_var.halo_depth, setting_var.coefficient, rx, ry,
            chunk_var[0].u, chunk_var[0].u0, chunk_var[0].energy, chunk_var[0].density, chunk_var[0].kx, chunk_var[0].ky, Domain);

        copy_u(chunk_var[0].x, chunk_var[0].y, setting_var.halo_depth, chunk_var[0].u, chunk_var[0].u0);

        // Need to update for the matvec
        reset_fields_to_exchange(setting_var);
        setting_var.fields_to_exchange[FIELD_U] = true;
    }

    // Invokes the main Jacobi solve kernels
    proc jacobi_main_step_driver (ref chunk_var : [0..<setting_var.num_chunks] chunks.Chunk, ref setting_var : settings.setting, const in tt: int,
    ref err: real, const in Domain : domain(2)){
        jacobi_iterate(chunk_var[0].x, chunk_var[0].y, setting_var.halo_depth, chunk_var[0].u, chunk_var[0].u0, 
            chunk_var[0].r, err, chunk_var[0].kx, chunk_var[0].ky, Domain);

        if tt % 50 == 0 {
            halo_update_driver(chunk_var, setting_var, 1);

            calculate_residual(chunk_var[0].x, chunk_var[0].y, setting_var.halo_depth, chunk_var[0].u, chunk_var[0].u0, chunk_var[0].r,
                chunk_var[0].kx, chunk_var[0].ky);
            
            calculate_2norm(chunk_var[0].x, chunk_var[0].y, setting_var.halo_depth, chunk_var[0].r, err);
        }
    }

}