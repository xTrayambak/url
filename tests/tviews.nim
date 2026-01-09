import pkg/url/views

let x = "hello world!"
let view = toStringView(x)

echo view[0]
echo view.endsWith('!')
echo view.endsWith('e')
echo view.slice(0, 4)
