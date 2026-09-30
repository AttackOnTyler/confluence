using Godot;

public partial class Spin : MeshInstance3D
{
    public override void _Ready()
    {
        GD.Print("spin ready");
    }

    public override void _Process(double delta)
    {
        RotateY((float)delta);
    }
}
