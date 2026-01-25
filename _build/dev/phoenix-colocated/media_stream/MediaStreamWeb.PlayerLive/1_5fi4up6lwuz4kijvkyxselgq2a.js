
    export default {
      mounted() {
        this.el.addEventListener('click', (e) => {
          const rect = this.el.getBoundingClientRect();
          const clickX = e.clientX - rect.left;
          const percentage = clickX / rect.width;
          const duration = parseFloat(this.el.dataset.duration) || 0;
          const position = percentage * duration;

          // Send seek event to server
          this.pushEvent('seek_to_position', { position: position });

          // Also seek the audio element directly for immediate feedback
          const audio = document.getElementById('audio-player');
          if (audio) {
            audio.currentTime = position;
          }
        });
      }
    }
  