function Uploader(holder, update){
    holder.ondragover = function () { this.className = 'hover'; return false; };
    holder.ondragend = function () { this.className = ''; return false; };
    holder.ondrop = function (e) {
        e.preventDefault();
        this.readfiles(e.dataTransfer.files, update);
    }.bind(this)
    this.update = update;
}

Uploader.prototype.readfiles = function(files, update) {
    var file = files[0];
    console.log('Uploaded ' + file.name + ' ' + (file.size ? (file.size/1024|0) + 'K' : ''));
    var reader = new FileReader();
    reader.onload = function (event) {
        update(event.target.result)
    };
    reader.readAsArrayBuffer(file);
}