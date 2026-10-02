# README media

- `demo.gif` — the app in action, recorded with `demo/demo.mkv`
- `no-ffprobe.png`, `no-ffmpeg.png` — error states

## Re-recording

1. Regenerate the demo video if needed: `demo/make.sh`
2. Build and start the app on its start screen: `./build.sh && open "build/Video Inspector.app"`
3. Record the window as video (MP4) at 2× resolution: drop the demo file, then click General → Video (scroll) → Audio → Subtitles → Cover Art → General.
4. Convert to GIF with a palette made from the recording (keeps UI text sharp):

   ```
   ffmpeg -i recording.mp4 -vf "fps=15,scale=900:-1:flags=lanczos,split[a][b];[a]palettegen=stats_mode=diff[p];[b][p]paletteuse=dither=sierra2_4a" docs/demo.gif
   ```

5. Error states: temporarily rename `ffprobe` (start screen shows "ffprobe Not Found"), or only `ffmpeg` (open the demo file, General tab shows the thumbnail warning), take a window screenshot, rename back.
