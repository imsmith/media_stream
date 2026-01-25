
    export default {
      mounted() {
        const audio = this.el;
        this.lastSrc = audio.src;
        this.pendingPlay = false;
        console.log('[AudioPlayer] mounted, src:', audio.src, 'data-playing:', audio.dataset.playing);

        // Handle play event
        audio.addEventListener('play', () => {
          console.log('[AudioPlayer] play event fired');
          this.pushEvent('audio_playing', {});
        });

        // Handle pause event
        audio.addEventListener('pause', () => {
          console.log('[AudioPlayer] pause event fired');
          this.pushEvent('audio_paused', {});
        });

        // Handle errors
        audio.addEventListener('error', (e) => {
          console.error('[AudioPlayer] error:', audio.error?.message, audio.error?.code);
        });

        // Handle time updates - throttle to reduce server load
        let lastUpdate = 0;
        audio.addEventListener('timeupdate', () => {
          const now = Date.now();
          if (now - lastUpdate > 1000) {
            this.pushEvent('audio_time_update', {
              position: audio.currentTime
            });
            lastUpdate = now;
          }
        });

        // Handle track ended
        audio.addEventListener('ended', () => {
          this.pushEvent('audio_ended', {});
        });

        // Handle loaded metadata (for duration)
        audio.addEventListener('loadedmetadata', () => {
          console.log('[AudioPlayer] metadata loaded, duration:', audio.duration);
          this.pushEvent('audio_metadata_loaded', {
            duration: audio.duration
          });
        });

        // Handle canplay - this is when we can actually start playing
        audio.addEventListener('canplay', () => {
          console.log('[AudioPlayer] canplay fired, pendingPlay:', this.pendingPlay);
          if (this.pendingPlay) {
            this.pendingPlay = false;
            this.doPlay();
          }
        });

        // Check if we should auto-play on mount
        this.maybePlay();
      },

      updated() {
        const audio = this.el;
        const isActivePlayer = audio.dataset.isActivePlayer === 'true';
        console.log('[AudioPlayer] updated, src:', audio.src, 'isActivePlayer:', isActivePlayer, 'data-playing:', audio.dataset.playing);

        // Check if src changed (new track)
        if (audio.src !== this.lastSrc) {
          console.log('[AudioPlayer] src changed, loading new track');
          this.lastSrc = audio.src;
          // Only set pendingPlay if we're the active player
          this.pendingPlay = audio.dataset.playing === 'true' && isActivePlayer;
          audio.load();
        } else {
          this.maybePlay();
        }
      },

      maybePlay() {
        const audio = this.el;
        const shouldPlay = audio.dataset.playing === 'true';
        const isActivePlayer = audio.dataset.isActivePlayer === 'true';
        console.log('[AudioPlayer] maybePlay - shouldPlay:', shouldPlay, 'isActivePlayer:', isActivePlayer, 'paused:', audio.paused);

        // Only play audio if this device is the active player
        if (shouldPlay && isActivePlayer && audio.paused) {
          // Check if audio is ready to play
          if (audio.readyState >= 2) {
            this.doPlay();
          } else {
            console.log('[AudioPlayer] audio not ready, setting pendingPlay');
            this.pendingPlay = true;
            audio.load();
          }
        } else if ((!shouldPlay || !isActivePlayer) && !audio.paused) {
          // Pause if we shouldn't be playing OR if we're not the active player
          console.log('[AudioPlayer] pausing - shouldPlay:', shouldPlay, 'isActivePlayer:', isActivePlayer);
          audio.pause();
        }
      },

      doPlay() {
        const audio = this.el;
        const isActivePlayer = audio.dataset.isActivePlayer === 'true';
        // Double-check we're still the active player before playing
        if (!isActivePlayer) {
          console.log('[AudioPlayer] doPlay aborted - not active player');
          return;
        }
        console.log('[AudioPlayer] doPlay called, readyState:', audio.readyState);
        audio.play()
          .then(() => console.log('[AudioPlayer] play() succeeded'))
          .catch(err => console.error('[AudioPlayer] Play failed:', err));
      }
    }
  