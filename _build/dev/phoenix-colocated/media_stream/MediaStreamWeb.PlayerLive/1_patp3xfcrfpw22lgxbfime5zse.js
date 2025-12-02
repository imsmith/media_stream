
    export default {
      mounted() {
        const audio = this.el;

        // Handle play event
        audio.addEventListener('play', () => {
          this.pushEvent('audio_playing', {});
        });

        // Handle pause event
        audio.addEventListener('pause', () => {
          this.pushEvent('audio_paused', {});
        });

        // Handle time updates
        audio.addEventListener('timeupdate', () => {
          this.pushEvent('audio_time_update', {
            position: audio.currentTime
          });
        });

        // Handle track ended
        audio.addEventListener('ended', () => {
          this.pushEvent('audio_ended', {});
        });

        // Handle loaded metadata (for duration)
        audio.addEventListener('loadedmetadata', () => {
          this.pushEvent('audio_metadata_loaded', {
            duration: audio.duration
          });
        });
      },

      updated() {
        const audio = this.el;
        const shouldPlay = this.el.dataset.playing === 'true';

        if (shouldPlay && audio.paused) {
          audio.play().catch(err => console.log('Play failed:', err));
        } else if (!shouldPlay && !audio.paused) {
          audio.pause();
        }
      }
    }
  