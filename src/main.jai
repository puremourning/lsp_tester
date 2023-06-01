DT_MAX : float = 0.3333;

main :: () {
  #if OS == .WINDOWS {
    Windows :: #import "Windows";
    Windows.SetProcessDPIAware();

    // Windows is very bad at thread-switching by default unless you do this.
    Windows.timeBeginPeriod(1);
  }

  window := create_window( window_width, window_height, "LSP Tester" );

  Simp.set_render_target( window );
  set_cwd();
  init_time();
  // init_fonts();
  ui_init();

  quit := false;
  last_time: float64;

  while !quit {
    reset_temporary_storage();

    current_time := get_time();
    current_dt : float = cast(float)(current_time - last_time);
    if current_dt > DT_MAX current_dt = DT_MAX;

    delay : float = DT_MAX - current_dt;
    if delay > 0.001 {
      // wait; we don't want to do too many pesky frames
      // TODO: THis is probably wrong/lame.
      sleep_for : s32 = xx ( delay * 1000.0 + 0.5 );
      sleep_milliseconds( sleep_for );
    }

    // Frame starts now, however shitty the above timer/sleep is
    last_time = get_time();

    // TODO:
    // for get_window_resizes() {
    //    foo
    // }

    Math.Clamp( *current_dt, 0, 0.1 );

    Input.update_window_events();

    draw_frame( current_dt );

    Simp.swap_buffers( window );
  }

}

#scope_file;

draw_frame :: ( dt: float ) {
  Simp.clear_render_target( .7, .7, .7, 1 );
}

set_cwd :: () {
  System :: #import "System";
  set_working_directory(System.get_path_of_running_executable());
}

window_width := 1024;
window_height := 768;


#import "Window_Creation";
#import "Basic";
#import "GetRect";

Math:: #import "Math";
Simp :: #import "Simp";
Input :: #import "Input";
