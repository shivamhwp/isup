### add command

```
isup add https://example.com --interval 30 --notify email
isup list
isup remove https://example.com
isup status
```

### steps needed :

1. add the command using clap.
2. things needed to make it work: a db to store the urls and the statuses, last pinged time. [ for storage ]
3. we need a bg servie which keeps track of different url's given by the users.
   so if i think, should there be a backend service on the machine or on the server. on the machine is cost efficient.

so let's say if a user adds adds a site -> we start a bg process which keeps running in the bg. the process should be lightweight and shoulf take almost zero cpu and memory.
i think this should be async, can handle concurrency

4. the whole point of the thread or the process in the bg is to just ping it every certain time interval and when its down, send a on device or email or discord or any other given media.

### some q's to ask:

1. why do we need this : Efficient sleep patterns that wake only when needed
2. Checks are distributed over time to avoid CPU spikes, how and why?
3. Efficient sleep patterns that only wake when needed, where and how are they making the code efficient.

# todo [ what have we done till now ]

[x] stop-ms command : to stop the process
[x] add-command with configurable options
[x] status
[x] list

done.
