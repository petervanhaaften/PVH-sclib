/*
quitting sclang+scsynth via osc
following this thread: https://scsynth.org/t/input-sampling-rate-does-not-match-the-output/562/2
*/

OSCFunc.newMatching({s.quit; 0.exit;}, '/s_quit')

b = NetAddr.new("192.168.1.117", 57120); // create the NetAddr

b.sendMsg("/s_quit");