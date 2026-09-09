for s in ["/dav/Duplicati/%23Photo/x.zip"; "/remote.php/dav/files/u/My%20Folder/x.zip"; "/plain/Folder/x.zip"] do
    let ok, u = System.Uri.TryCreate(s, System.UriKind.Absolute)
    if ok then printfn "%s -> IsFile=%b AbsolutePath=%s" s u.IsFile u.AbsolutePath else printfn "%s -> not absolute" s
