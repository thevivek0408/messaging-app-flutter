// Simple Node.js socket.io server for one-on-one chat
const io = require('socket.io')(3000, {
  cors: { origin: '*' }
});
console.log('Socket.io server started on port 3000');

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('message', (data) => {
    // Broadcast the message to all other clients except sender
    socket.broadcast.emit('message', data);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});
