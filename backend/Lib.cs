using SpacetimeDB;

public static partial class Module
{
    [Table(Name = "greeting", Accessor = "Greeting", Public = true)]
    public partial struct Greeting
    {
        [AutoInc]
        [PrimaryKey]
        public uint Id;
        public string Text;
    }

    [Reducer]
    public static void AddGreeting(ReducerContext ctx, string text)
    {
        ctx.Db.Greeting.Insert(new Greeting { Text = text });
    }

    [Reducer(ReducerKind.Init)]
    public static void Init(ReducerContext ctx)
    {
        ctx.Db.Greeting.Insert(new Greeting { Text = "hello from the seed row" });
    }
}
