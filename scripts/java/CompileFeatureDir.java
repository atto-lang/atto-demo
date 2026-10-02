import dev.oreslang.compiler.IncrementalCompiler;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.Map;

public final class CompileFeatureDir {
    private CompileFeatureDir() { }

    public static void main(String[] args) throws Exception {
        if (args.length != 1) {
            throw new IllegalArgumentException("usage: CompileFeatureDir <directory>");
        }

        Path root = Path.of(args[0]).toAbsolutePath().normalize();
        if (!Files.isDirectory(root)) {
            throw new IllegalArgumentException("not a directory: " + root);
        }

        Map<String, String> units = new LinkedHashMap<>();
        try (var paths = Files.walk(root)) {
            for (Path path : paths.filter(Files::isRegularFile)
                    .filter(path -> path.getFileName().toString().endsWith(".ores"))
                    .sorted(Comparator.comparing(Path::toString))
                    .toList()) {
                String unit = root.relativize(path).toString().replace('\\', '/');
                units.put(unit, Files.readString(path));
            }
        }

        if (units.isEmpty()) {
            throw new IllegalArgumentException("no .ores files found under " + root);
        }

        new IncrementalCompiler().compile(units);
        System.out.println("feature-compile-ok");
    }
}
