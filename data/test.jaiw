#load "src/main.jai";

#run {
  Compiler :: #import "Compiler";
  File :: #import "File";
  build_options := Compiler.get_build_options();

  // FIXME: better way to determine this ? THis is based on the following code
  // in the Default_Metaprogram:
  //        case "-release";
  //          set_optimization(*options, .OPTIMIZED);
  //          options.stack_trace = false;

  target := ifx build_options.stack_trace == true "debug" else "release";

  output_dir := tprint( "bin/%/%/%", OS, CPU, target );
  File.make_directory_if_it_does_not_exist( output_dir, recursive = true );
  Compiler.set_build_options_dc(
    .{
      output_executable_name = "lsp_tester",
      output_path = output_dir,
    }
  );
}
