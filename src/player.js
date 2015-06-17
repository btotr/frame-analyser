function Player(videoElm){
    this.video = videoElm;
    this.mediaSource = new MediaSource();
    this.mediaSource.queue = [];
    this.video.src = window.URL.createObjectURL(this.mediaSource);
    this.fps = 0;

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


Player.prototype.init = function(buffer){
    buffer.fileStart = 0;
    var mp4box = new MP4Box();
    var self = this;
    mp4box.onReady = function(info) {
        self.fps = window.fps;
        document.body.classList.add("playMode");
        this.setSegmentOptions(1, null, { nbSamples: 10, rapAlignement: true } );
        self.mediaSource.buffer = self.mediaSource.addSourceBuffer('video/mp4; codecs=\"'+info.tracks[0].codec+'\"');
        self.mediaSource.buffer.addEventListener("updateend", function(){ player.nextChunk(); });
        mp4box.onSegment = function (id, sb, buffer) { self.appendBuffer(buffer); }
        self.appendBuffer(this.initializeSegmentation()[0].buffer);
    }
    mp4box.appendBuffer(buffer);
    mp4box.flush();
}


Player.prototype.appendBuffer = function(buffer){
   console.log("append")
   if (this.mediaSource.buffer.updating) {
        this.mediaSource.queue.push(buffer);
        if (this.mediaSource.buffer.updating) return
    }
    
    if (this.mediaSource.queue.length == 0) {
        this.mediaSource.queue.push(buffer);
        this.nextChunk(buffer)
    }
}

Player.prototype.nextChunk = function(){
        console.log("next")
        if (this.mediaSource.queue.length > 0) {
            this.mediaSource.buffer.appendBuffer(this.mediaSource.queue.shift())
        }
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

Player.prototype.seekFrames = function(frames) {
    if (this.video.paused == false) {
        this.video.pause();
    }
    var currentFrames = Math.round(this.video.currentTime * this.fps);
    this.video.currentTime = (currentFrames + frames) / this.fps;
    console.log("SMPTE time", this.secondsToTimecode(this.video.currentTime));
}