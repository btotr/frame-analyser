function Overlay(){
    this.data = null;
    this.x = 0;
    this.y = 0;
    this.number = 0;
    this.UTC = 0;
    this.flip = 0;
    this.clear = 0;
    this.rect = 0;
    this.rects = 0;
    this.alpha = 0;
    this.index = 0;
}

Overlay.prototype.getData = function(){
    return this.data;
}

function OverlayPlayer(videoElm){
    Player.call(this, videoElm);
    
    this.cues = [];
    this.overlays = [];
    this.shadowBuffer = [];
    
    // add canvas
    this.canvas = document.createElement("canvas");
    this.canvas.setAttribute("width", 1280);
    this.canvas.setAttribute("height", 720);
    document.body.appendChild(this.canvas);
    this.context = this.canvas.getContext('2d');
    
    
    // reset framebuffer on first update
    this.video.addEventListener("timeupdate", function(){
        if(this.video.currentTime == 0) {
            console.log("reset framebuffer");
            this.frameBuffer = [];
            this.context.clearRect(0,0, 1280, 720);    
        }
    }.bind(this))
    
    // cues are to slow while playing use animationframe instead
    var cueIndex = 0;
    function checkCue() {
        if(this.video.textTracks[0]){
            var cue = this.video.textTracks[0].cues[cueIndex];
            if (cue.startTime <= this.video.currentTime && cue.endTime >= this.video.currentTime) {
                this.renderOverlay(this.getOverlay(parseInt(cue.text)));
                cueIndex++
            }
        }
        if (this.video.paused == false) {
            window.requestAnimationFrame(checkCue.bind(this));
        }
    }
    this.video.addEventListener("canplay",function(){
        window.requestAnimationFrame(checkCue.bind(this));    
    }.bind(this))
    
    this.video.addEventListener("pause",function(){
        this.video.textTracks[0].addEventListener("cuechange", function (e) {
         for (var i=0, l=e.currentTarget.activeCues.length;i<l;i++){
             this.renderOverlay(this.getOverlay(parseInt(e.currentTarget.activeCues[i].text)));
         }
        }.bind(this), false);
    }.bind(this))
    
    
    
}

OverlayPlayer.prototype = Object.create(Player.prototype);

OverlayPlayer.prototype.create = function(buffer, images){
    // only initialize if we have video data
    if (buffer) this.init(buffer);
    
    // add text track to use cues for overlays
    var overlayCues = this.video.addTextTrack('metadata'); 

    // add overlays
    for (var i=0, l=images.length;i<l;i++){
        this.addOverlay(i, images[i]);
    }
    
    // add cues in the correct order
    var self = this;
    var ordered = Object.keys(self.cues).sort(function(a,b){return self.cues[a]-self.cues[b]});
    for (var i=0, l=this.cues.length;i<l;i++){
        var cue = this.cues[ordered[i]]
        var startTime = cue -  this.cues[ordered[0]];
        
        var endTime = 0;
        endTime : for (var t=i+1, k=this.cues.length;t<k;t++){
            var nextStartTime = this.cues[ordered[t]]-  this.cues[ordered[0]];
            if(startTime != nextStartTime) {
                endTime = nextStartTime;
                break endTime
            }
        }
        overlayCues.addCue(new VTTCue(startTime, endTime, ordered[i])); 
    }
}

OverlayPlayer.prototype.getOverlay = function(index) {
    for (var i=0, l=this.overlays.length;i<l;i++){
        if (this.overlays[i].index == index) {
            return this.overlays[i]
        }
    } 
}

OverlayPlayer.prototype.addOverlay = function(index, image) {
    var overlay = new Overlay();
    var meta = image.name.match(/.*#([0-9].*)-UTC=(.*)-Flip=(.*)\ Clear=(.*)\ Rect=(.*)\ Alpha=(.*)\ Rects=(.*)\ Loc=([0-9].*)x([0-9].*)\ S/)
    overlay.index = index;
    overlay.number = meta[1];
    overlay.UTC = meta[2];
    overlay.flip = meta[3];
    overlay.clear = meta[4];
    overlay.rect = meta[5];
    overlay.alpha = meta[6];
    overlay.rects = meta[7];
    overlay.x = meta[8];
    overlay.y = meta[9];
    
    this.cues[index] = overlay.UTC;
    this.overlays.push(overlay);
    
    var reader = new FileReader();
    reader.onload = function(e) {
        overlay.data = reader.result;
    }.bind(this)
    
    reader.readAsDataURL(image);
}

OverlayPlayer.prototype.renderOverlay = function(overlay) {
    var img = new Image();
    var self = this;
    img.onload = function() {
        self.shadowBuffer.push({"image": this, "x": overlay.x, "y": overlay.y})
        if (overlay.rect != overlay.rects) return

        if (overlay.clear == "true"){
            console.log('clear')
            self.context.clearRect(0,0, 1280, 720);    
        }

        if (overlay.flip == "true") {
            console.log('flip')
            self.context.clearRect(0,0, 1280, 720);
            for (var i=0, l=self.shadowBuffer.length;i<l;i++){
                var schadowBuffer = self.shadowBuffer[i]
                self.context.drawImage(schadowBuffer.image, schadowBuffer.x, schadowBuffer.y);
            }
            self.shadowBuffer = [];
        } 
    }
    img.src =  overlay.data;
}