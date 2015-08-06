function Uploader(holder, update){
    holder.ondragover = function () { this.className = 'hover'; return false; };
    holder.dragend = function () { console.log("test"); this.className = ''; return false; };
    holder.ondrop = function (e) {
        document.body.classList.add("playMode");
        e.preventDefault();
        this.readfiles(e.dataTransfer.files, update);
    }.bind(this)
    this.update = update;
}

Uploader.prototype.readfiles = function(files, update) {
    var ts;
    var images = [];
    
    for (var i=0, l=files.length;i<l;i++){
        var file = files[i];
        if (file.type == "image/png" || file.type == "image/bmp") {
            images.push(file);
            continue;
        }
        // otherwise ts (no file type)
        ts = file;
    }
    if (!ts){
        update(null, images);
        return;
    }
    
    console.log('Uploaded ' + ts.name + ' ' + (ts.size ? (ts.size/1024|0) + 'K' : ''));
    var reader = new FileReader();
    reader.onload = function (event) {
        update(event.target.result, images);
    };
    reader.readAsArrayBuffer(ts);
}