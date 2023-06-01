FRAME_TICK := 1.0/30.0; // update at around 30fps.
VER_MAJOR  := 1;
VER_MINOR  := 0;

main :: () {
  #if OS == .WINDOWS {
    Windows :: #import "Windows";
    Windows.SetProcessDPIAware();

    // Windows is very bad at thread-switching by default unless you do this.
    Windows.timeBeginPeriod(1);
  }

  {
    ok: bool;
    ok, options = parse_arguments( Options, .ALIGN_HELP );
    if !ok {
      log_error( "Unable to parse command line" );
      exit( 1 );
    }
  }

  if !init_simple_logging( options.log_level ) {
    exit( 1 );
  }
  log( .VERBOSE, "normal LSP Tester v%.%", VER_MAJOR, VER_MINOR );

  window := create_window( window_width, window_height, "LSP Tester" );

  {
    x, y, w, h := get_dimensions(window, false);
    window_width = w;
    window_height = h;
  }

  Simp.set_render_target( window );
  set_cwd();
  init_time();
  init_fonts();
  ui_init();

  quit := false;
  last_time: float64;

  while !quit {
    reset_temporary_storage();

    current_time := get_time();
    current_dt : float = cast(float)(current_time - last_time);
    if current_dt > FRAME_TICK current_dt = FRAME_TICK;

    delay : float = FRAME_TICK - current_dt;
    if delay > 0.001 {
      // wait; we don't want to do too many pesky frames
      sleep_for : s32 = xx ( delay * 1000.0 + 0.5 );
      // TODO: THis is probably wrong/lame. Timers are so shitty, but it's
      // probably close enough for this sort of app.
      sleep_milliseconds( sleep_for );
    }

    // Frame starts now, however shitty the above timer/sleep is
    last_time = get_time();

    for Input.get_window_resizes() {
      Simp.update_window(it.window);
      if it.window == window {
        should_reinit := ( it.width != window_width ) ||
                         ( it.height != window_height );

        window_width  = it.width;
        window_height = it.height;

        if should_reinit init_fonts();
      }
    }

    Input.update_window_events();
    for Input.events_this_frame {
      if #complete it.type == {
        case .UNINITIALIZED;
          // ignore
        case .KEYBOARD;
          if it.key_pressed && it.key_code == .ESCAPE quit = true;
        case .TEXT_INPUT;
        case .WINDOW;
        case .MOUSE_WHEEL;
        case .QUIT; quit = true;
        case .DRAG_AND_DROP_FILES;
      }
    }

    draw_frame( current_dt );
    Simp.swap_buffers( window );
  }

}

#scope_file;

Options :: struct {
  runtime_dir := ".";           @"?Runtime directory of this application";
  data_dir    := "data";        @"?Directory under runtime_dir";
  log_level   := "NORMAL";      @"?Levels: NORMAL, VERBOSE, VERY_VERBOSE";
}
options: Options;

draw_frame :: ( dt: float ) {
  Simp.clear_render_target( .7, .7, .7, 1 );

  font := fonts[ Font_Style.NORMAL ];
  text_width := Simp.prepare_text( font, "Hello, Sailor!" );

  text_x := ( window_width - text_width ) / 2.0;
  text_y := window_height * 0.9 - font.character_height / 2.0;
  Simp.draw_prepared_text( font, xx text_x, xx text_y );
}

Font_Style :: enum {
  NORMAL;
  MONO;
};

set_cwd :: () {
  if options.runtime_dir && set_working_directory( options.runtime_dir ) {
    return;
  }

  System :: #import "System";
  set_working_directory(System.get_path_of_running_executable());
}

init_fonts :: () {
  // there seems to be no way to free Dynamic_Fonts. shrug.
  array_reset( *fonts );

  pixel_height := window_height / 24;

  // Generate a call to load each font in Font_Style
  #insert #run -> string {
    builder: String_Builder;

    load_one :: #string DONE
    {
      font := Simp.get_font_at_size( options.data_dir, "%1.ttf", pixel_height );
      if !font {
        log_error( "Unable to load font %1" );
        exit( 1 );
      }
      array_add( *fonts, font );
    }
    DONE

    defer reset( *builder );
    for em : type_info( Font_Style ).names {
      append( *builder, tprint( load_one, em ) );
    }
    return builder_to_string( *builder );
  };

  log( .VERBOSE, "Loaded % fonts from %", fonts.count, options.data_dir );
}

fonts : [..]*Simp.Dynamic_Font;
window_width := 1280;
window_height := 720;

#import "Window_Creation";
#import "Basic";
#import "GetRect";
#import "Command_Line";
#import "Simple_Logger";

Math:: #import "Math";
Simp :: #import "Simp";
Input :: #import "Input";
