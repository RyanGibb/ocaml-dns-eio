open Printf

module Make (Aio : sig
  val accept : Unix.file_descr -> Unix.file_descr * Unix.sockaddr
  val recv   : Unix.file_descr -> bytes -> int -> int -> Unix.msg_flag list -> int
  val send   : Unix.file_descr -> bytes -> int -> int -> Unix.msg_flag list -> int
  val fork   : (unit -> unit) -> unit
  val run    : (unit -> unit) -> unit
  val non_blocking_mode : bool
end) = struct
  let send sock str =
    let len = Bytes.length str in
    let total = ref 0 in
    (try
        while !total < len do
          let write_count = Aio.send sock str !total (len - !total) [] in
          total := write_count + !total
        done
      with _ -> ()
      );
    !total

  let recv sock maxlen =
    let str = Bytes.create maxlen in
    let recvlen =
      try Aio.recv sock str 0 maxlen []
      with _ -> 0
    in
    Bytes.sub str 0 recvlen

  let close sock =
    try Unix.shutdown sock Unix.SHUTDOWN_ALL
    with _ -> () ;
    Unix.close sock

  let string_of_sockaddr = function
    | Unix.ADDR_UNIX s -> s
    | Unix.ADDR_INET (inet,port) ->
        (Unix.string_of_inet_addr inet) ^ ":" ^ (string_of_int port)

  let rec client_handler sock addr =
    try
      let data = recv sock 1024 in
      if Bytes.length data > 0 then 
        (ignore (send sock (Bytes.cat (Bytes.of_string ("server says: ")) data));
        client_handler sock addr)
      else
        let cn = string_of_sockaddr addr in
        (printf "client_handler : client (%s) disconnected.\n%!" cn;
        close sock)
    with
    | _ -> close sock

  let server () =
    let addr, port = Unix.inet_addr_loopback, 53 in
    printf "Server listening on 127.0.0.1:%d\n" port;
    let saddr = Unix.ADDR_INET (addr, port) in
    let ssock = Unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    (* SO_REUSEADDR so we can restart the server quickly. *)
    Unix.setsockopt ssock Unix.SO_REUSEADDR true;
    Unix.bind ssock saddr;
    Unix.listen ssock 20;
    (* Socket is non-blocking *)
    if Aio.non_blocking_mode then Unix.set_nonblock ssock;
    try
      (* Wait for clients, and fork off echo servers. *)
      while true do
        let client_sock, client_addr = Aio.accept ssock in
        let cn = string_of_sockaddr client_addr in
        printf "server : client (%s) connected.\n%!" cn;
        if Aio.non_blocking_mode then Unix.set_nonblock client_sock;
        Aio.fork (fun () -> client_handler client_sock client_addr)
      done
    with
    | e ->
        print_endline @@ Printexc.to_string e;
        close ssock

  let start () = Aio.run server
end

module M = Make(struct
  let accept fd = Unix.accept fd
  let recv = Unix.recv
  let send = Unix.send
  let fork f = f ()
  let run f = f ()
  let non_blocking_mode = false
end)

let _ = M.start ()
