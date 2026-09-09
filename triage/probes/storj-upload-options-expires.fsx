#r "uplink.NET.dll"
open System.Reflection
let show (label: string) (o: uplink.NET.Models.UploadOptions) =
    let m = o.GetType().GetMethod("ToSWIG", BindingFlags.Instance ||| BindingFlags.NonPublic ||| BindingFlags.Public)
    let swig = m.Invoke(o, [||])
    let p = swig.GetType().GetProperty("expires")
    printfn "%s: Expires=%O -> swig expires=%O" label o.Expires (p.GetValue(swig))
show "new UploadOptions()" (uplink.NET.Models.UploadOptions())
show "Expires=UnixEpoch" (uplink.NET.Models.UploadOptions(Expires = System.DateTime.UnixEpoch))
