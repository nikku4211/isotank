.RODATA
.align 256
qubo_x:
  .byte 1
  .byte 1
  .byte 1
  .byte 1
  .byte 63
  .byte 63
  .byte 63
  .byte 63
qubo_y:
  .byte 63
  .byte 0
  .byte 63
  .byte 0
  .byte 63
  .byte 0
  .byte 63
  .byte 0
qubo_z:
  .byte 63
  .byte 63
  .byte 1
  .byte 1
  .byte 63
  .byte 63
  .byte 1
  .byte 1

qubo_edge1:
  .byte 0,4,6,2
  .byte 3,2,6,7
  .byte 7,6,4,5
  .byte 5,1,3,7
  .byte 1,0,2,3
  .byte 5,4,0,1

qubo_edge2:
  .byte 4,6,2,0
  .byte 2,6,7,3
  .byte 6,4,5,7
  .byte 1,3,7,5
  .byte 0,2,3,1
  .byte 4,0,1,5

qubo_faces:
  .byte 0,1,0
  .byte 0,0,1
  .byte 255,0,0
  .byte 0,255,0
  .byte 1,0,0
  .byte 0,0,255


qubo_vertex_count:
  .byte 8

qubo_edge_count:
  .byte 12
