module cg_driver {
    use cg;
    use settings;
    use chunks;
    use local_halos;
    use solver_methods;
    //TODO ADD PROFILING

    // Performs a full solve with the CG solver kernels
    proc cg_driver (ref chunk_var : chunks.Chunk, ref setting_var : settings.setting, ref rx: real,
    ref ry: real, ref error: real){
        //var tt: int;
        var rro : real;
        var t : int;

        // Perform CG initialisation
        cg_init_driver(chunk_var, setting_var, rx, ry, rro);
        
        var tt_prime : int;
        // Iterate till convergence
        for tt in 0..<setting_var.max_iters do {
            
            cg_main_step_driver(chunk_var, setting_var, tt, rro, error);

            halo_update_driver (chunk_var, setting_var, 1);

            if (sqrt(abs(error)) < setting_var.eps) then break;

            tt_prime += 1;
        }
        writeln("CG iterations : ", tt_prime);
    }

    // Invokes the CG initialisation kernels
    proc cg_init_driver (ref chunk_var : chunks.Chunk, ref setting_var : settings.setting, ref rx: real,
    ref ry: real, ref rro: real) {

        // var sharedrxry = (rx, ry);
        rro = 0.0;

        // for cc in {0..<setting_var.num_chunks_per_rank} do {
        cg_init(chunk_var.x, chunk_var.y, setting_var.halo_depth, setting_var.coefficient, rx, ry, rro,
        chunk_var.density, chunk_var.energy, chunk_var.u, chunk_var.p, chunk_var.r, chunk_var.w,
        chunk_var.kx, chunk_var.ky);
        // }

        // Need to update for the matvec
        reset_fields_to_exchange(setting_var);
        setting_var.fields_to_exchange[FIELD_U] = true;
        setting_var.fields_to_exchange[FIELD_P] = true;
        halo_update_driver(chunk_var, setting_var, 1);

        //sum over ranks TODO This seems to be an MPI things, so ignore for now

        // for cc in {0..<setting_var.num_chunks_per_rank} do {
        copy_u(chunk_var.x, chunk_var.y, setting_var.halo_depth, chunk_var.u, chunk_var.u0);
        // }

    }

    // Invokes the main CG solve kernels
    proc cg_main_step_driver (ref chunk_var : chunks.Chunk, ref setting_var : settings.setting, in tt : int,
    ref rro: real, ref error: real){
        var pw: real;
        
        // for cc in {0..<setting_var.num_chunks_per_rank} do {
            
        cg_calc_w (chunk_var.x, chunk_var.y, setting_var.halo_depth, pw, chunk_var.p, chunk_var.w, chunk_var.kx,
            chunk_var.ky, {0..<chunk_var.y, 0..<chunk_var.x});
            
        // }
        //MPI sum over ranks function

        var alpha : real = rro / pw;
        
        var rrn: real;
    

        // for cc in {0..<setting_var.num_chunks_per_rank} do {
        chunk_var.cg_alphas[tt] = alpha;

        cg_calc_ur(chunk_var.x, chunk_var.y, setting_var.halo_depth, alpha, rrn, chunk_var.u, chunk_var.p,
            chunk_var.r, chunk_var.w, {0..<chunk_var.y, 0..<chunk_var.x});
        // }

        var beta : real = rrn / rro;
        
        // for cc in {0..<setting_var.num_chunks_per_rank} do {
        chunk_var.cg_betas[tt] = beta;
        cg_calc_p (chunk_var.x, chunk_var.y, setting_var.halo_depth, beta, chunk_var.p,
            chunk_var.r, {0..<chunk_var.y, 0..<chunk_var.x});
        // }
        
        error = rrn;
        rro = rrn;
    }

}