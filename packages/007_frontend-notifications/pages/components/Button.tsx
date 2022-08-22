const Button = (props: any) => (
  <button
    {...props}
    className="border rounded border-slate-300 hover:border-slate-500 px-2 mt-2"
  >
    {props.children}
  </button>
)
export default Button
