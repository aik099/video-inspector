# README media

- `demo.gif` — the app in action, inspecting `demo/demo.mkv`
- `start-screen.png` — start screen, no file open
- `no-ffprobe.png` — start screen when `ffprobe` is missing
- `demo/backdrop.png` — backdrop with a window-shaped hole, for framing `demo.gif`
- `demo/make-gif.sh` — recording → framed `demo.gif`

## Re-recording

1. Regenerate the demo video if needed: `demo/make.sh`
2. Build and start the app on its start screen: `./build.sh && open "build/Video Inspector.app"`
3. Record the window as video (MP4), e.g. with CleanShot: drop the demo file, then click General → Video (scroll) → Audio → Subtitles → Cover Art → General; optionally open more files as tabs.
4. Make the GIF (recording into `demo/backdrop.png`, then palette GIF; about 3 s):

   ```
   docs/demo/make-gif.sh recording.mp4 2   # first 2 s only, to check
   docs/demo/make-gif.sh recording.mp4     # writes docs/demo.gif
   ```

   `demo/backdrop.png` is the CleanShot gradient + shadow with a transparent, window-shaped hole (560×708, window at 10,10, 540×688), 1 px smaller than the window so its clean edge covers the recording's gray window border. The recording must be 540×688 (the script checks). A lossless intermediate keeps the backdrop static, so the GIF stays small; `stats_mode=full` gives the static gradient its share of the 256 colors (`diff` leaves it dithered).

   Format notes (70 s recording): GIF 5.0 MB looked best. Lossy WebP (~2.5 MB) shows color fringes on sharp UI edges; lossless/near-lossless WebP is no smaller (4.9–5.9 MB); WebP from H.264 also needs `scale=in_color_matrix=bt709` or colors shift. MP4 doesn't play in a README when committed (GitHub serves repo files as `application/octet-stream`).

5. Screenshots: window only, then CleanShot's background (same gradient, 10 px padding); for `no-ffprobe.png` temporarily rename `ffprobe` and relaunch, then rename it back.
