<?php
session_start();
require_once '../config/database.php';

// Handle post creation
if ($_POST && isset($_POST['title']) && isset($_POST['content'])) {
    if (!isset($_SESSION['user_id'])) {
        $error = "You must be logged in to create posts";
    } else {
        $title = trim($_POST['title']);
        $content = trim($_POST['content']);
        
        if (empty($title) || empty($content)) {
            $error = "Title and content are required";
        } else {
            try {
                $stmt = $pdo->prepare("INSERT INTO posts (user_id, title, content) VALUES (?, ?, ?)");
                $result = $stmt->execute([$_SESSION['user_id'], $title, $content]);
                
                if ($result) {
                    $success = "Post created successfully!";
                } else {
                    $error = "Failed to create post";
                }
            } catch (Exception $e) {
                $error = "Error creating post: " . $e->getMessage();
            }
        }
    }
}

// Get all posts with user information
$stmt = $pdo->prepare("
    SELECT p.*, u.username 
    FROM posts p 
    JOIN users u ON p.user_id = u.id 
    ORDER BY p.created_at DESC
");
$stmt->execute();
$posts = $stmt->fetchAll();
?>
<!DOCTYPE html>
<html>
<head>
    <title>Blog Posts</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
        .header { background: #333; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; display: flex; justify-content: space-between; align-items: center; }
        .header h1 { margin: 0; }
        .auth-links { display: flex; gap: 10px; }
        .btn { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 4px; cursor: pointer; text-decoration: none; display: inline-block; }
        .btn:hover { background: #0056b3; }
        .btn-secondary { background: #6c757d; }
        .btn-secondary:hover { background: #545b62; }
        .alert { padding: 10px; border-radius: 4px; margin-bottom: 20px; }
        .alert-success { background: #d4edda; color: #155724; border: 1px solid #c3e6cb; }
        .alert-error { background: #f8d7da; color: #721c24; border: 1px solid #f5c6cb; }
        .create-post { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .form-group { margin-bottom: 15px; }
        .form-group label { display: block; margin-bottom: 5px; font-weight: bold; }
        .form-group input, .form-group textarea { width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 4px; font-size: 16px; }
        .form-group textarea { min-height: 100px; resize: vertical; }
        .posts-container { display: flex; flex-direction: column; gap: 20px; }
        .post-card { background: white; border-radius: 8px; padding: 20px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .post-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px; }
        .post-title { margin: 0; color: #333; }
        .post-meta { color: #666; font-size: 14px; }
        .post-content { line-height: 1.6; color: #555; }
        .no-posts { text-align: center; padding: 40px; color: #666; }
    </style>
</head>
<body>
    <div class="header">
        <h1>Blog Posts</h1>
        <div class="auth-links">
            <?php if (isset($_SESSION['user_id'])): ?>
                <span>Welcome, <?= htmlspecialchars($_SESSION['username']) ?>!</span>
                <a href="logout.php" class="btn btn-secondary">Logout</a>
            <?php else: ?>
                <a href="login.php" class="btn">Login</a>
                <a href="register.php" class="btn btn-secondary">Register</a>
            <?php endif; ?>
        </div>
    </div>

    <?php if (isset($success)): ?>
        <div class="alert alert-success"><?= $success ?></div>
    <?php endif; ?>
    
    <?php if (isset($error)): ?>
        <div class="alert alert-error"><?= $error ?></div>
    <?php endif; ?>

    <?php if (isset($_SESSION['user_id'])): ?>
        <div class="create-post">
            <h2>Create New Post</h2>
            <form method="POST">
                <div class="form-group">
                    <label for="title">Title:</label>
                    <input type="text" id="title" name="title" required maxlength="255">
                </div>
                <div class="form-group">
                    <label for="content">Content:</label>
                    <textarea id="content" name="content" required placeholder="Write your post content here..."></textarea>
                </div>
                <button type="submit" class="btn">Create Post</button>
            </form>
        </div>
    <?php endif; ?>

    <h2>All Posts (<?= count($posts) ?>)</h2>
    <div class="posts-container">
        <?php if (empty($posts)): ?>
            <div class="no-posts">
                <p>No posts yet. <?= isset($_SESSION['user_id']) ? 'Be the first to create one!' : 'Please login to create the first post.' ?></p>
            </div>
        <?php else: ?>
            <?php foreach ($posts as $post): ?>
                <div class="post-card">
                    <div class="post-header">
                        <h3 class="post-title"><?= htmlspecialchars($post['title']) ?></h3>
                        <div class="post-meta">
                            by <?= htmlspecialchars($post['username']) ?> • 
                            <?= date('M j, Y g:i A', strtotime($post['created_at'])) ?>
                        </div>
                    </div>
                    <div class="post-content">
                        <?= nl2br(htmlspecialchars($post['content'])) ?>
                    </div>
                </div>
            <?php endforeach; ?>
        <?php endif; ?>
    </div>
</body>
</html>