function Player(videoElm, fps){
    this.fps = fps;
    this.video = videoElm;

    // update workaround
    var canvas = document.createElement("canvas");
    canvas.setAttribute("width", 1280);
    canvas.setAttribute("height", 720);
    this.video.parentNode.insertBefore(canvas, this.video.nextElementSibling);
    var context = canvas.getContext('2d');

    function forceVideoUpdate() {
        context.clearRect(0,0, 1280, 720);
        window.requestAnimationFrame(forceVideoUpdate);
    }
    window.requestAnimationFrame(forceVideoUpdate);
}

Player.prototype.secondsToTimecode = function(time){
    var hours = Math.floor(time / 3600) % 24;
    var minutes = Math.floor(time / 60) % 60;
    var seconds = Math.floor(time % 60);
    var frames = Math.floor(((time % 1) * this.fps).toFixed(3));
    var result = (hours < 10 ? "0" + hours : hours) +
    ":" + (minutes < 10 ? "0" + minutes : minutes) +
    ":" + (seconds < 10 ? "0" + seconds : seconds) +
    ":" + (frames < 10 ? "0" + frames : frames);
    return result;    
}

Player.prototype.setSource = function(src) {
    this.video.src = src;
}

Player.prototype.seekFrames = function(frames) {
    if (this.video.paused == false) {
        this.video.pause();
    }
    var currentFrames = Math.round(this.video.currentTime * this.fps);
    this.video.currentTime = (currentFrames + frames) / this.fps;
    console.log("SMPTE time", this.secondsToTimecode(this.video.currentTime));
}