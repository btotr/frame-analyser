# frame analyser

analyse a video frame by frame

# usage

use the up and down keys to skip 1 second, left and right 1 frame.

# workflow

## start tcpdump between server and client

first start to capture the data through tcpdum
    
`tcpdump -w capture.pcap`

start the client and copy the capture to your local machine

## genarate the data 

on your local machine install wireshark (with rfbtv plugin) and ffmpeg

`sudo rm -rf /tmp/* && tshark -2 -R "tcp.port==8090" -r capture.pcap -T fields -e data | tr -d '\n' | perl -pe 's/([0-9a-f]{2})/chr hex $1/gie' | ffmpeg -i pipe:0 -loglevel panic  -map 0:0 -vcodec copy /tmp/cloudtv.ts`

this will create some files in your /tmp folder

select all and drop it in the analyser

http://video-analyser-btotr.c9.io/