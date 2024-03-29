(* X86lite Simulator *)

(* See the documentation in the X86lite specification, available on the 
   course web pages, for a detailed explanation of the instruction
   semantics.
*)

open X86

(* simulator machine state -------------------------------------------------- *)

let mem_bot = 0x400000L          (* lowest valid address *)
let mem_top = 0x410000L          (* one past the last byte in memory *)
let mem_size = Int64.to_int (Int64.sub mem_top mem_bot)
let nregs = 17                   (* including Rip *)
let ins_size = 8L                (* assume we have a 8-byte encoding *)
let exit_addr = 0xfdeadL         (* halt when m.regs(%rip) = exit_addr *)

(* Your simulator should raise this exception if it tries to read from or
   store to an address not within the valid address space. *)
exception X86lite_segfault

(* The simulator memory maps addresses to symbolic bytes.  Symbolic
   bytes are either actual data indicated by the Byte constructor or
   'symbolic instructions' that take up four bytes for the purposes of
   layout.

   The symbolic bytes abstract away from the details of how
   instructions are represented in memory.  Each instruction takes
   exactly eight consecutive bytes, where the first byte InsB0 stores
   the actual instruction, and the next sevent bytes are InsFrag
   elements, which aren't valid data.

   For example, the two-instruction sequence:
        at&t syntax             ocaml syntax
      movq %rdi, (%rsp)       Movq,  [~%Rdi; Ind2 Rsp]
      decq %rdi               Decq,  [~%Rdi]

   is represented by the following elements of the mem array (starting
   at address 0x400000):

       0x400000 :  InsB0 (Movq,  [~%Rdi; Ind2 Rsp])
       0x400001 :  InsFrag
       0x400002 :  InsFrag
       0x400003 :  InsFrag
       0x400004 :  InsFrag
       0x400005 :  InsFrag
       0x400006 :  InsFrag
       0x400007 :  InsFrag
       0x400008 :  InsB0 (Decq,  [~%Rdi])
       0x40000A :  InsFrag
       0x40000B :  InsFrag
       0x40000C :  InsFrag
       0x40000D :  InsFrag
       0x40000E :  InsFrag
       0x40000F :  InsFrag
       0x400010 :  InsFrag
*)
type sbyte = InsB0 of ins       (* 1st byte of an instruction *)
           | InsFrag            (* 2nd - 7th bytes of an instruction *)
           | Byte of char       (* non-instruction byte *)

(* memory maps addresses to symbolic bytes *)
type mem = sbyte array

(* Flags for condition codes *)
type flags = { mutable fo : bool
             ; mutable fs : bool
             ; mutable fz : bool
             }

(* Register files *)
type regs = int64 array

(* Complete machine state *)
type mach = { flags : flags
            ; regs : regs
            ; mem : mem
            }

(* simulator helper functions ----------------------------------------------- *)

(* The index of a register in the regs array *)
let rind : reg -> int = function
  | Rip -> 16
  | Rax -> 0  | Rbx -> 1  | Rcx -> 2  | Rdx -> 3
  | Rsi -> 4  | Rdi -> 5  | Rbp -> 6  | Rsp -> 7
  | R08 -> 8  | R09 -> 9  | R10 -> 10 | R11 -> 11
  | R12 -> 12 | R13 -> 13 | R14 -> 14 | R15 -> 15

(* Helper functions for reading/writing sbytes *)

(* Convert an int64 to its sbyte representation *)
let sbytes_of_int64 (i:int64) : sbyte list =
  let open Char in 
  let open Int64 in
  List.map (fun n -> Byte (shift_right i n |> logand 0xffL |> to_int |> chr))
           [0; 8; 16; 24; 32; 40; 48; 56]

(* Convert an sbyte representation to an int64 *)
let int64_of_sbytes (bs:sbyte list) : int64 =
  let open Char in
  let open Int64 in
  let f b i = match b with
    | Byte c -> logor (shift_left i 8) (c |> code |> of_int)
    | _ -> 0L
  in
  List.fold_right f bs 0L

(* Convert a string to its sbyte representation *)
let sbytes_of_string (s:string) : sbyte list =
  let rec loop acc = function
    | i when i < 0 -> acc
    | i -> loop (Byte s.[i]::acc) (pred i)
  in
  loop [Byte '\x00'] @@ String.length s - 1

(* Serialize an instruction to sbytes *)
let sbytes_of_ins (op, args:ins) : sbyte list =
  let check = function
    | Imm (Lbl _) | Ind1 (Lbl _) | Ind3 (Lbl _, _) -> 
      invalid_arg "sbytes_of_ins: tried to serialize a label!"
    | o -> ()
  in
  List.iter check args;
  [InsB0 (op, args); InsFrag; InsFrag; InsFrag; InsFrag; InsFrag; InsFrag; InsFrag]

(* Serialize a data element to sbytes *)
let sbytes_of_data : data -> sbyte list = function
  | Quad (Lit i) -> sbytes_of_int64 i
  | Asciz s -> sbytes_of_string s
  | Quad (Lbl _) -> invalid_arg "sbytes_of_data: tried to serialize a label!"


(* It might be useful to toggle printing of intermediate states of your 
   simulator. *)
let debug_simulator = ref true

(* Interpret a condition code with respect to the given flags. *)
let interp_cnd {fo; fs; fz} : cnd -> bool = fun x ->
  begin match x with
    | Eq -> if fz == true then true
            else false
    | Neq -> if fz == true then false
            else true
    | Gt -> if not(fs != fo || fz) then true
            else false
    | Lt -> if fo != fs then true
            else false
    | Ge -> if not(fs != fo) then true
            else false
    | Le -> if (fo != fs || fz) then true
            else false
  end


(* Maps an X86lite address into Some OCaml array index,
   or None if the address is not within the legal address space. *)
let map_addr (addr:quad) : int option =
   if (addr > mem_top) then None
   else if (addr < mem_bot) then None 
   else Some (Int64.to_int (Int64.rem addr 1048576L))

(* Simulates one step of the machine:
    - fetch the instruction at %rip
    - compute the source and/or destination information from the operands
    - simulate the instruction semantics
    - update the registers and/or memory appropriately
    - set the condition flags
*)
let getIndex (x:int option) : int = 
 match x with
 | None -> failwith "error"
 | Some y -> y


let valueof (m:mach) (oper:operand): int64 = 
    match oper with
    | Imm (Lit x) -> x
    (*  Imm (Lbl x) -> 0L   Apparently don't need to worry about this case *)
    | Reg x -> m.regs.(rind x)   (*  need to get value out of register *)        
    | Ind1 (Lit x) ->  let addr = map_addr x in
                       let index = getIndex addr in 
                            int64_of_sbytes [m.mem.(index); m.mem.(index+1); m.mem.(index+2 ); m.mem.(index+3); m.mem.(index+4 ); m.mem.(index+5); m.mem.(index+6 ); m.mem.(index+7)  ]

    | Ind2 x ->  let addr = map_addr m.regs.(rind x) in
                 let index = getIndex addr in 
                      int64_of_sbytes [m.mem.(index); m.mem.(index+1); m.mem.(index+2 ); m.mem.(index+3); m.mem.(index+4 ); m.mem.(index+5); m.mem.(index+6 ); m.mem.(index+7)  ]
   
    | Ind3 (Lit x, r)  -> let off = Int64.add x  m.regs.(rind r) in
                          let addr = map_addr off in
                          let index = getIndex addr in 
                            int64_of_sbytes [m.mem.(index); m.mem.(index+1); m.mem.(index+2 ); m.mem.(index+3); m.mem.(index+4 ); m.mem.(index+5); m.mem.(index+6 ); m.mem.(index+7)  ]
                         
    | _ -> failwith "Invalid input to valueof function" 
        
let memHelp m destOp result : unit = 
 begin match destOp with 
  | Reg x -> Array.set m.regs (rind x) result
  | Ind1 (Lit x ) ->  let addr = map_addr x in
                      let index = getIndex addr in 
                      let bytes =  (sbytes_of_int64 result) in
                                    for i = 0 to 7 do
                                      m.mem.(index + i) <- List.nth bytes i
                                    done
                    
  | Ind2 x ->  let addr = map_addr m.regs.(rind x) in
                let index = getIndex addr in 
                let bytes =  (sbytes_of_int64 result) in
                              for i = 0 to 7 do
                                m.mem.(index + i) <- List.nth bytes i
                              done

  | Ind3(Lit x,r) -> let off = Int64.add x  m.regs.(rind r) in
                      let addr = map_addr off in
                      let index = getIndex addr in 
                      let bytes =  (sbytes_of_int64 result) in
                                    for i = 0 to 7 do
                                      m.mem.(index + i) <- List.nth bytes i
                                    done
  | _ -> failwith "Dest must be an addr or reg"
end


let movIns (m:mach) (opers:operand list): unit =
  match opers with
    | (srcOp::destOp::_) ->  let result = (valueof m srcOp) in
                             memHelp m destOp result
    | _ -> raise X86lite_segfault 


let signOf (x:int64): bool = 
  if x >= 0L then false
  else true

let unsetAllFlags (m:mach): unit = 
  let setFs = m.flags.fs <- false in 
  let setFz = m.flags.fz <- false in
  m.flags.fz <- false
let setBitFlags (m:mach) (ftype:string) (amt:int64) (dest:int64)(result:int64) =
  if amt = 0L then ()
  else match ftype with
      | "sarq" -> let newFs = signOf result in
                  let newFz = Int64.equal result 0L in
                  let setFs = m.flags.fs <- newFs in 
                  let setFz = m.flags.fz <- newFz in
                  if amt == 1L then m.flags.fo <- false
      | "shlq" -> let newFs = signOf result in
                  let newFz = Int64.equal result 0L in
                  let setFs = m.flags.fs <- newFs in 
                  let setFz = m.flags.fz <- newFz in
                  let sigTwoBits = Int64.shift_right dest 62 in
                  if amt == 1L then m.flags.fo <- ((Int64.equal sigTwoBits 1L) || (Int64.equal sigTwoBits 2L))
      | "shrq" -> let newFs = signOf result in
                  let newFz = Int64.equal result 0L in
                  let setFs = m.flags.fs <- newFs in 
                  let setFz = m.flags.fz <- newFz in
                  let sigBit = Int64.shift_right dest 63 in 
                  if amt == 1L then
                               if Int64.equal sigBit 1L then m.flags.fo <- true
                               else m.flags.fo <- false
let setFlags (m:mach) (ftype:string) (result:int64) (dest:int64) (src:int64): unit =
  match ftype with
    | "neg" -> let newFz = Int64.equal result 0L in
               let newFs = signOf result in
               let setFz = m.flags.fz <- newFz in
               let setFs = m.flags.fs <- newFs in
               let overflow = Int64_overflow.neg result in
               m.flags.fo <- overflow.overflow
    | "incq"
    | "add" -> let newFo = ((signOf src == signOf dest) && (signOf src != signOf result)) in
               let newFs = signOf result in
               let newFz = Int64.equal result 0L in
               let setFo = m.flags.fo <- newFo in 
               let setFz = m.flags.fz <- newFz in
               m.flags.fs <- newFs
    | "decq" 
    | "sub" -> let newFo = (((signOf dest == signOf (Int64.neg src)) && ((signOf (Int64.neg src) != signOf result)))
                      || Int64.equal src (Int64.min_int)) in
               let newFs = signOf result in
               let newFz = result == 0L in
               let setFo = m.flags.fo <- newFo in 
               let setFz = m.flags.fz <- newFz in
               m.flags.fs <- newFs
    | "mul" -> let overflow = Int64_overflow.mul src dest in
               let setFo = m.flags.fo <- overflow.overflow in 
               let setFz = m.flags.fz <- false in
               m.flags.fs <- false;
    | "and" 
    | "or" 
    | "xor" -> let newFs = signOf result in
               let newFz = Int64.equal result 0L in
               let setFo = m.flags.fo <- false in 
               let setFz = m.flags.fz <- newFz in
               m.flags.fs <- newFs

(*This handles interpretation of arithmatic operands, also works for logical operands*)
let domath (ftype:string) (func: (int64 -> int64 -> int64)) (m:mach) (opers:operand list): unit =
  match opers with
    | (srcOp::destOp::_) -> let destval = valueof m destOp in
                            let srcval = valueof m srcOp in
                            let result = func destval srcval  in
                            let setflags= setFlags m ftype  result destval srcval in
                            memHelp m destOp result                      
    |(srcOp::[]) ->         let destval = Int64.minus_one in
                            let srcval = valueof m srcOp in
                            let result = func destval srcval  in
                            let setflags= setFlags m ftype  result destval srcval in
                            memHelp m srcOp result
    | _ -> raise X86lite_segfault 

(*Since notq uses lognot which is int64 -> int64 , i need another thing*)
let notIns  (m:mach) (opers:operand list): unit =
  let setFlags = unsetAllFlags m in 
  match opers with
  | (srcOp::[]) -> let result = (Int64.lognot (valueof m srcOp) ) in
                   memHelp m srcOp result
    | _ -> raise X86lite_segfault 

(*This handles the bitshift operands, since their int64 functions have a different type  *)
let doshift (func: (int64 -> int -> int64)) (m:mach) (opers:operand list): unit =
  match opers with
    | (srcOp::destOp::_) -> let result = func (valueof m destOp) (Int64.to_int(valueof m srcOp)) in
                            memHelp m destOp result
    | _ -> raise X86lite_segfault  

let dopush (m:mach) (opers:operand list): unit =
  match opers with
  | (srcOp::[]) -> let curr = m.regs.(rind Rsp) in
                   let result = valueof m srcOp in
                   let temp =  m.regs.(rind Rsp) <- (Int64.sub curr  8L) in
                   let index = getIndex (map_addr m.regs.(rind Rsp)) in
                   let bytes =  (sbytes_of_int64 result) in
                      for i = 0 to 7 do
                        m.mem.(index + i) <- List.nth bytes i
                      done
  
    | _ -> raise X86lite_segfault        

let dopop (m:mach) (opers:operand list): unit =
  match opers with
    | (destOp::[]) -> let index = getIndex (map_addr m.regs.(rind Rsp)) in
                      let result =  int64_of_sbytes [m.mem.(index); m.mem.(index+1); m.mem.(index+2 ); m.mem.(index+3); m.mem.(index+4 ); m.mem.(index+5); m.mem.(index+6 ); m.mem.(index+7)  ] in
                      let temp = m.regs.(rind Rsp) <- Int64.add m.regs.(rind Rsp) 8L in
                      memHelp m destOp result        
    | _ -> raise X86lite_segfault   


let doload (m:mach) (opers:operand list): unit =
  match opers with
  |  ( ind::destOp::_) -> begin match ind with 
                            | Ind1 (Lit x ) ->  memHelp m destOp x                                         
                            | Ind2 x ->   memHelp m destOp (m.regs.(rind x))                                 
                            | Ind3(Lit x,r) -> let off = Int64.add x  m.regs.(rind r) in
                                                memHelp m destOp off
                          end 
  | _ -> raise X86lite_segfault
  
let doSetB (m:mach) (cc:cnd) (opers:operand list) =
  match opers with 
  | (destOp::_) -> if (interp_cnd m.flags cc)  then memHelp m destOp (Int64.logand (valueof m destOp) 0b1111111111111111111111111111111111111111111111111111111111111110L)
                    else memHelp m destOp (Int64.logor (valueof m destOp) 1L)
  | _ -> raise X86lite_segfault


let doJump (m:mach) (opers: operand list) =
  match opers with
  | (srcOp::_) -> let num = valueof m srcOp in 
                  m.regs.(rind Rip) <- num
  | _ -> raise X86lite_segfault
                
  
let doJumpCnd (m:mach) (cc:cnd) (opers: operand list) = 
 match opers with
 | (srcOp::_) -> let num = valueof m srcOp in
                if (interp_cnd m.flags cc)  then  m.regs.(rind Rip) <- num
                else ()
 | _ -> raise X86lite_segfault

 let doCmp (m:mach) (opers:operand list)=
  match opers with 
   | (srcOp::destOp::_) -> let destval = valueof m destOp in
                            let srcval = valueof m srcOp in
                            let result = Int64.sub destval  srcval in
                            let print = Printf.printf "result is : %LX\n" result in
                            setFlags m "sub" result destval srcval 
   | _ -> raise X86lite_segfault

 
let doCallq (m:mach) (opers:operand list) =
 match opers with
 |(srcOp::_) -> let curr = m.regs.(rind Rsp) in
                let result = valueof m srcOp in
                let decStack =  m.regs.(rind Rsp) <- (Int64.sub curr  8L) in
                let index = getIndex (map_addr m.regs.(rind Rsp)) in
                let bytes =  (sbytes_of_int64 curr) in
                let setRip = m.regs.(rind Rip) <- result in
                for i = 0 to 7 do
                  m.mem.(index + i) <- List.nth bytes i
                done
  | _ -> raise X86lite_segfault


let step (m:mach) : unit =
 let byte =  m.regs.(rind Rip) in
 let addr = map_addr byte in
 let index = getIndex addr in 
 let temp = m.regs.(rind Rip) <- Int64.add byte 8L in 
 let instruct = Array.get m.mem index in
 match instruct with 
 | InsB0 x -> let opcode, operands = x in
              begin match opcode with 
              | Movq -> movIns m operands
              | Pushq -> dopush m operands
              | Popq -> dopop m operands
              | Leaq -> doload m operands
              | Incq -> domath  "inc" (Int64.sub) m operands
              | Decq -> domath  "dec" (Int64.add) m operands
              | Negq -> domath "neg" (Int64.mul) m operands
              | Notq -> notIns m operands
              | Addq -> domath "add" (Int64.add) m operands
              | Subq -> domath "sub" (Int64.sub) m operands
              | Imulq -> domath "mul" (Int64.mul) m operands
              | Xorq -> domath "xor" (Int64.logxor) m operands
              | Orq -> domath "or" (Int64.logor) m operands
              | Andq -> domath "and" (Int64.logand) m operands
              | Jmp -> doJump m operands
              | J (cnd) -> doJumpCnd m cnd operands
              | Cmpq -> doCmp m operands
              | Shlq -> doshift (Int64.shift_left) m operands
              | Shrq -> doshift (Int64.shift_right) m operands
              | Sarq -> doshift (Int64.shift_right_logical) m operands
              | Set (cnd) -> doSetB m cnd operands
              | Callq -> doCallq m operands
              | Retq -> let index = getIndex (map_addr m.regs.(rind Rsp)) in
                        let result =  int64_of_sbytes [m.mem.(index); m.mem.(index+1); m.mem.(index+2 ); m.mem.(index+3); m.mem.(index+4 ); m.mem.(index+5); m.mem.(index+6 ); m.mem.(index+7)  ] in
                        let temp = m.regs.(rind Rsp) <- Int64.add m.regs.(rind Rsp) 8L in
                        m.regs.(rind Rip) <- result    
              | _ -> failwith "NYI"
              end
 | _ -> raise X86lite_segfault
 
(* Runs the machine until the rip register reaches a designated
   memory address. *)
let run (m:mach) : int64 = 
  while m.regs.(rind Rip) <> exit_addr do step m done;
  m.regs.(rind Rax)

(* assembling and linking --------------------------------------------------- *)

(* A representation of the executable *)
type exec = { entry    : quad              (* address of the entry point *)
            ; text_pos : quad              (* starting address of the code *)
            ; data_pos : quad              (* starting address of the data *)
            ; text_seg : sbyte list        (* contents of the text segment *)
            ; data_seg : sbyte list        (* contents of the data segment *)
            }

(* Assemble should raise this when a label is used but not defined *)
exception Undefined_sym of lbl

(* Assemble should raise this when a label is defined more than once *)
exception Redefined_sym of lbl

(* Convert an X86 program into an object file:
   - separate the text and data segments
   - compute the size of each segment
      Note: the size of an Asciz string section is (1 + the string length)

   - resolve the labels to concrete addresses and 'patch' the instructions to 
     replace Lbl values with the corresponding Imm values.

   - the text segment starts at the lowest address
   - the data segment starts after the text segment

  HINT: List.fold_left and List.fold_right are your friends.
 *)
let assemble (p:prog) : exec =
failwith "assemble unimplemented"

(* Convert an object file into an executable machine state. 
    - allocate the mem array
    - set up the memory state by writing the symbolic bytes to the 
      appropriate locations 
    - create the inital register state
      - initialize rip to the entry point address
      - initializes rsp to the last word in memory 
      - the other registers are initialized to 0
    - the condition code flags start as 'false'

  Hint: The Array.make, Array.blit, and Array.of_list library functions 
  may be of use.
*)
let load {entry; text_pos; data_pos; text_seg; data_seg} : mach = 
failwith "load unimplemented"
