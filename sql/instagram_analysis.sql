use ig_clone;
-- Objective Questions

-- 1.	Are there any tables with duplicate or missing null values? If so, how would you handle them?


desc comments;
select * from comments where created_at is null;
select user_id, photo_id, comment_text, count(*)
from comments
group by  user_id, photo_id, comment_text
having count(*) > 1;

desc follows;
select * from follows where created_at is null;

desc likes;
select * from likes where created_at is null;

desc photo_tags;

desc photos;
select user_id, image_url, count(*)
from photos
group by  user_id, image_url
having count(*) > 1;

desc tags;
select * from tags where created_at is null;

desc users;
select * from users where created_at is null;
select username, count(*)
from users
group by  username
having count(*) > 1;



-- 2. What is the distribution of user activity levels (e.g., number of posts, likes, comments) across the user base?

create view user_activity_summary as
with cte1 as 
(
select photo_id, count(*)  as like_count 
from likes
group by photo_id
),
cte2 as 
(
select photo_id, count(*)  as comments_count 
from comments
group by photo_id
)

select  u.id as user_id,  count(p.id) as count_post, coalesce(sum(c1.like_count),0) as likes_got, coalesce(sum(c2.comments_count),0) as comments_got
from users u
left join photos p on u.id = p.user_id
left join cte1 c1 on p.id = c1.photo_id
left join cte2 c2 on p.id = c2.photo_id
group by u.id
;
select *,
CASE
WHEN count_post >= 5  AND (likes_got >= 150 OR comments_got >= 140)THEN 'Highly Active User'
WHEN count_post BETWEEN 1 AND 4 THEN 'Moderately Active User'
ELSE 'Inactive User'
END AS user_activity_type
from user_activity_summary;


-- 3.Calculate the average number of tags per post (photo_tags and photos tables).

 
with no_of_tags_per_post_available as 
(
select photo_id, count(tag_id) as no_of_tags
from photo_tags
group by photo_id
),
tags_per_post_alluser as 
(
select p.id  , coalesce(no_of_tags,0) as tag_per_post
from photos p 
left join no_of_tags_per_post_available pt on p.id = pt.photo_id
)

select avg(tag_per_post) as average_number_of_tags_per_post
from tags_per_post_alluser;


-- 4.	Identify the top users with the highest engagement rates (likes, comments) on their posts and rank them.
-- engagement rate = (likes + comments) / posts

select *,
coalesce((likes_got + comments_got) / count_post,0) as engagement_rate,
rank() over(order by coalesce((likes_got + comments_got) / count_post,0) desc ) as rnk
from user_activity_summary
limit 1;



-- 5.	Which users have the highest number of followers and followings?

with following_count_for_user as
( 
select follower_id as user_id, count(followee_id) as following_count
from follows
group by follower_id
)
select user_id, following_count 
from following_count_for_user where following_count =  (select max(following_count) from following_count_for_user);

with followers_count_for_users as
(
select followee_id as user_id, count(follower_id) as followers_count
from follows
group by followee_id
)

select user_id, followers_count 
from followers_count_for_users where followers_count =  (select max(followers_count) from followers_count_for_users);

-- 6.	Calculate the average engagement rate (likes, comments) per post for each user.

select *,
coalesce((likes_got + comments_got) / count_post,0) as engagement_rate_per_post
from user_activity_summary;


-- 7.	Get the list of users who have never liked any post (users and likes tables)

select id, username 
from users where id not in ( 
select distinct user_id from likes);

-- 8.	How can you leverage user-generated content (posts, hashtags, photo tags) to create more personalized and engaging ad campaigns?

with like_count as (
select photo_id, count(*) as likes_count_photo_wise
from likes
group by photo_id
),
comment_count as ( 
select photo_id, count(*) as comments_count_photo_wise
from comments
group by photo_id
),
all_metric as (
select t.tag_name,sum(lc.likes_count_photo_wise) as count_likes,sum(cc.comments_count_photo_wise) as count_comments,count(distinct pt.photo_id) as count_post
from photo_tags pt
join tags t on t.id = pt.tag_id
join like_count lc on lc.photo_id = pt.photo_id
join comment_count cc on cc.photo_id = pt.photo_id
group by t.tag_name
)
select tag_name,count_likes,count_comments,count_post,
(count_likes + count_comments) as total_engagement,
ROUND((count_likes + count_comments) / count_post,2) as avg_engagement_per_post
from all_metric
order by  avg_engagement_per_post desc;


-- 9.	Are there any correlations between user activity levels and specific content types (e.g., photos, videos, reels)? How can this information guide content creation and curation strategies?

with photo_metrics as (
select p.id as photo_id,count(distinct l.user_id) as like_count,count(distinct c.id) as comment_count
from photos p
left join likes l on p.id = l.photo_id
left join comments c on p.id = c.photo_id
group by p.id
),
photo_with_tags as (
select pm.photo_id,pm.like_count,pm.comment_count,t.tag_name
from photo_metrics pm
join photo_tags pt on pm.photo_id = pt.photo_id
join tags t on pt.tag_id = t.id
)

select tag_name,count(distinct photo_id) as no_of_posts,sum(like_count) as total_likes,
sum(comment_count) as total_comments,round(sum(like_count) / count(distinct photo_id), 2) as avg_likes_per_post,
round(sum(comment_count) / count(distinct photo_id), 2) as avg_comments_per_post
from photo_with_tags
group by tag_name
order by avg_likes_per_post desc;

-- 10.	Calculate the total number of likes, comments, and photo tags for each user.


with tag_count as (
select u.id, count(pt.tag_id) as tags_count
from users u
left join photos p on u.id = p.user_id
left join photo_tags pt on p.id = pt.photo_id
group by u.id
)

select  u.*, tc.tags_count
from user_activity_summary u 
join tag_count tc on u.user_id = tc.id ;

-- 11.	Rank users based on their total engagement (likes, comments, shares) over a month.


create view user_engament_content_month_wise as 
WITH post_count AS
(
    SELECT 
        user_id,
        MONTH(created_dat) AS month,
        COUNT(*) AS total_posts
    FROM photos
    GROUP BY user_id, MONTH(created_dat)
),

like_count AS
(
    SELECT 
        user_id,
        MONTH(created_at) AS month,
        COUNT(*) AS likes_given
    FROM likes
    GROUP BY user_id, MONTH(created_at)
),

comment_count AS
(
    SELECT 
        user_id,
        MONTH(created_at) AS month,
        COUNT(*) AS comments_given
    FROM comments
    GROUP BY user_id, MONTH(created_at)
),

likes_got AS
(
    SELECT  
        p.user_id,
        MONTH(l.created_at) AS month,
        COUNT(*) AS likes_got
    FROM likes l
    JOIN photos p
        ON l.photo_id = p.id
    GROUP BY p.user_id, MONTH(l.created_at)
),

comments_got AS
(
    SELECT  
        p.user_id,
        MONTH(c.created_at) AS month,
        COUNT(*) AS comments_got
    FROM comments c
    JOIN photos p
        ON c.photo_id = p.id
    GROUP BY p.user_id, MONTH(c.created_at)
)

SELECT 
    u.id AS user_id,

    m.month,

    COALESCE(pc.total_posts,0) AS total_posts,

    COALESCE(lc.likes_given,0) AS likes_given,

    COALESCE(cc.comments_given,0) AS comments_given,

    COALESCE(lg.likes_got,0) AS likes_got,

    COALESCE(cg.comments_got,0) AS comments_got,

    -- Weighted Engagement Score
    (
        COALESCE(pc.total_posts,0) * 5 +

        COALESCE(cc.comments_given,0) * 3 +

        COALESCE(lc.likes_given,0) * 1 +

        COALESCE(cg.comments_got,0) * 1 +

        COALESCE(lg.likes_got,0) * 0.5

    ) AS total_engagement,

    -- Monthly User Ranking
    RANK() OVER
    (
        PARTITION BY m.month

        ORDER BY
        (
            COALESCE(pc.total_posts,0) * 5 +

            COALESCE(cc.comments_given,0) * 3 +

            COALESCE(lc.likes_given,0) * 1 +

            COALESCE(cg.comments_got,0) * 1 +

            COALESCE(lg.likes_got,0) * 0.5

        ) DESC
    ) AS engagement_rank

FROM users u

CROSS JOIN
(
    SELECT DISTINCT MONTH(created_dat) AS month
    FROM photos

    UNION

    SELECT DISTINCT MONTH(created_at)
    FROM likes

    UNION

    SELECT DISTINCT MONTH(created_at)
    FROM comments

) m

LEFT JOIN post_count pc
    ON u.id = pc.user_id
   AND m.month = pc.month

LEFT JOIN like_count lc
    ON u.id = lc.user_id
   AND m.month = lc.month

LEFT JOIN comment_count cc
    ON u.id = cc.user_id
   AND m.month = cc.month

LEFT JOIN likes_got lg
    ON u.id = lg.user_id
   AND m.month = lg.month

LEFT JOIN comments_got cg
    ON u.id = cg.user_id
   AND m.month = cg.month

ORDER BY m.month, engagement_rank;

select * from user_engament_content_month_wise;




-- 12.	Retrieve the hashtags that have been used in posts with the highest average number of likes. Use a CTE to calculate the average likes for each hashtag first.

with like_count as
(		
select l.photo_id, count(l.photo_id) as no_of_likes
from  likes l 
group by l.photo_id
),
tag_avg_like as 
(
select t.tag_name, avg(lc.no_of_likes) as avg_likes
from like_count lc 
join photo_tags pt on lc.photo_id = pt.photo_id
join tags t on t.id = pt.tag_id
group by t.tag_name
)

select tag_name, avg_likes
from tag_avg_like
where avg_likes = (select max(avg_likes) from tag_avg_like);

-- 13.	Retrieve the users who have started following someone after being followed by that person

select f1.followee_id as user_A, f1.follower_id as user_B, f1.created_at as A_followed_B_time, f2.created_at as B_followed_A_time
from follows f1
join follows f2 
on f1.followee_id = f2.follower_id and f1.follower_id = f2.followee_id
where f2.created_at > f1.created_at;


-- Subjective Questions

--  1.	Based on user engagement and activity levels, which users would you consider the most loyal or valuable? How would you reward or incentivize these users?

create view user_level_engagement_content as
with cte1 as 
(
select user_id, sum(total_posts) as total_posts, sum(likes_given) as likes_given, sum(comments_given) as comments_given, sum(likes_got) as likes_got, sum(comments_got) as comments_got
from user_engament_content_month_wise
group by user_id
)

select *, 
(total_posts* 5 + comments_given * 3 + likes_given * 1 + comments_got * 1 +likes_got * 0.5) AS total_engagement,
rank() over(order by (total_posts* 5 + comments_given * 3 + likes_given * 1 + comments_got * 1 +likes_got * 0.5) desc) as engagement_rank
 from cte1 ;

select * from user_level_engagement_content;


-- 2.	For inactive users, what strategies would you recommend to re-engage them and encourage them to start posting or engaging again?

select * ,
CASE 
	WHEN total_engagement = 0 THEN 'Inactive User'
    WHEN total_engagement < 350 THEN 'Low Activity User'
    WHEN total_engagement BETWEEN 350 AND 700 THEN 'Moderately Active User'
    ELSE 'Highly Active User'
    END AS user_category
from user_level_engagement_content;



-- 3.	Which hashtags have the highest engagement rates? How can this information guide content strategy and ad campaigns?

with like_count as (
select photo_id , count(photo_id) as no_of_likes
from likes 
group by photo_id
),
comment_count as ( 
select photo_id as photo_id,count(photo_id) as no_of_comments
from comments  
group by photo_id
),
all_metric as (
select t.tag_name,sum(lc.no_of_likes) as count_likes,sum(cc.no_of_comments) as count_comments,count(distinct pt.photo_id) as count_post
from photo_tags pt
join tags t on t.id = pt.tag_id
join like_count lc on lc.photo_id = pt.photo_id
join comment_count cc on cc.photo_id = pt.photo_id
group by t.tag_name
)
select tag_name,count_likes,count_comments,count_post,
(count_likes + count_comments) as total_engagement,
ROUND((count_likes + count_comments) / count_post,2) as avg_engagement_per_post
from all_metric
order by  avg_engagement_per_post desc;


-- 4.	Are there any patterns or trends in user engagement based on demographics (age, location, gender) or posting times? How can these insights inform targeted marketing campaigns?
-- No  demographics details so we analyse on posting times

with like_count as (
select hour(created_at) as posting_hour,COUNT(*) as total_likes
from likes
group by hour(created_at)
order by total_likes desc
),
comment_count as ( 
select hour(created_at) as posting_hour,COUNT(*) as total_comments
from comments
group by hour(created_at)
order by total_comments desc
),
post_count as 
(
select hour(created_dat) as posting_hour, count(*) as total_post
from photos
group by hour(created_dat)
order by total_post desc
)
select lc.posting_hour, lc.total_likes,cc.total_comments,pc.total_post
from like_count lc 
join comment_count cc on lc.posting_hour = cc.posting_hour
join post_count pc on lc.posting_hour = pc.posting_hour;

-- 5.	Based on follower counts and engagement rates, which users would be ideal candidates for influencer marketing campaigns? How would you approach and collaborate with these influencers?

with follower_count as (
select followee_id as user_id,COUNT(follower_id) as followers_count
from follows
group by followee_id
),

influencer_metrics as (
select u.user_id,f.followers_count,u.total_posts,u.likes_got,u.comments_got,
-- Average likes per post
round(coalesce(u.likes_got / u.total_posts,0),2) as avg_likes_per_post,
-- Average comments per post
round(coalesce(u.comments_got / u.total_posts,0),2) as avg_comments_per_post,
-- Total engagement
(u.likes_got + u.comments_got) as total_engagement,
-- Engagement rate
round(((u.likes_got + u.comments_got) * 100.0)/ nullif(f.followers_count,0),2) as engagement_rate,
-- Influencer score
round(((u.likes_got * 0.4) +(u.comments_got * 0.4) +(u.total_posts * 0.2)),2) as influencer_score
from user_level_engagement_content u
join follower_count f on u.user_id = f.user_id
)
select user_id,followers_count,total_posts,likes_got,comments_got,avg_likes_per_post,avg_comments_per_post,total_engagement,engagement_rate,influencer_score
from influencer_metrics
order by influencer_score desc, engagement_rate desc;

-- 6.	Based on user behavior and engagement data, how would you segment the user base for targeted marketing campaigns or personalized recommendations

with liking_pref as (
SELECT l.user_id,t.tag_name,COUNT(*) as total_likes_on_tag
FROM likes l
JOIN photo_tags pt ON l.photo_id = pt.photo_id
JOIN tags t ON pt.tag_id = t.id
GROUP BY l.user_id, t.tag_name
),

comment_pref as (
SELECT c.user_id,t.tag_name,COUNT(*) as total_comments_on_tag
FROM comments c
JOIN photo_tags pt ON c.photo_id = pt.photo_id
JOIN tags t ON pt.tag_id = t.id
GROUP BY c.user_id, t.tag_name
),

combined_engagement as (
SELECT COALESCE(lp.user_id, cp.user_id) as user_id,COALESCE(lp.tag_name, cp.tag_name) as tag_name,COALESCE(lp.total_likes_on_tag, 0) as total_likes_on_tag,
COALESCE(cp.total_comments_on_tag, 0) as total_comments_on_tag,
(COALESCE(lp.total_likes_on_tag, 0) +COALESCE(cp.total_comments_on_tag, 0)) as engagement_score
FROM liking_pref lp
LEFT JOIN comment_pref cp ON lp.user_id = cp.user_id AND lp.tag_name = cp.tag_name

UNION

SELECT COALESCE(lp.user_id, cp.user_id) as user_id,COALESCE(lp.tag_name, cp.tag_name) as tag_name,COALESCE(lp.total_likes_on_tag, 0) as total_likes_on_tag,
COALESCE(cp.total_comments_on_tag, 0) as total_comments_on_tag,
(COALESCE(lp.total_likes_on_tag, 0) +COALESCE(cp.total_comments_on_tag, 0)) as engagement_score
FROM comment_pref cp
LEFT JOIN liking_pref lp ON lp.user_id = cp.user_id AND lp.tag_name = cp.tag_name
),

ranked_preferences as (
SELECT *,
ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY engagement_score DESC) as rank_num
FROM combined_engagement
)

SELECT user_id,tag_name as dominant_interest,total_likes_on_tag,total_comments_on_tag,engagement_score,
CASE 
WHEN engagement_score >= 80 THEN 'Highly Engaged Users'
WHEN engagement_score >= 40 THEN 'Moderately Engaged Users'
ELSE 'Low Engaged Users'
END AS user_segment,

CASE
WHEN tag_name IN ('food','foodie','delicious') THEN 'Food Lovers'
WHEN tag_name IN ('beach','sunrise','sunset','landscape') THEN 'Travel Enthusiasts'
WHEN tag_name IN ('fashion','style','beauty','hair')THEN 'Fashion Audience'
WHEN tag_name IN ('party','concert','fun','lol')THEN 'Entertainment Audience'
WHEN tag_name IN ('smile','happy','dreamy')THEN 'Lifestyle Audience'
ELSE 'General Users'
END as audience_type
FROM ranked_preferences
WHERE rank_num = 1
ORDER BY engagement_score DESC;

-- 8.	How can you use user activity data to identify potential brand ambassadors or advocates who could help promote Instagram's initiatives or events?

WITH follower_count AS (
SELECT followee_id AS user_id,COUNT(follower_id) AS followers_count
FROM follows
GROUP BY followee_id
),
brand_advocate_metrics AS (
SELECT u.user_id,f.followers_count,u.total_posts,u.likes_got,u.comments_got,
-- Average likes per post
ROUND(COALESCE(u.likes_got / NULLIF(u.total_posts,0),0),2) AS avg_likes_per_post,
-- Average comments per post
ROUND(COALESCE(u.comments_got / NULLIF(u.total_posts,0),0),2) AS avg_comments_per_post,
-- Total engagement
(u.likes_got + u.comments_got) AS total_engagement,
-- Engagement rate
ROUND(((u.likes_got + u.comments_got) * 100.0) / NULLIF(f.followers_count,0),2) AS engagement_rate,
-- Comment to like ratio
ROUND(COALESCE(u.comments_got / NULLIF(u.likes_got,0),0),2) AS comment_like_ratio,
-- Influencer score
ROUND(((u.likes_got * 0.4) +(u.comments_got * 0.4) +(u.total_posts * 0.2)),2) AS influencer_score,
-- Posting consistency score
ROUND((u.total_posts * 10),2) AS consistency_score,
-- Advocacy score
ROUND((((u.likes_got + u.comments_got) * 0.5) +(u.total_posts * 0.3) +(f.followers_count * 0.2)),2) AS advocacy_score
FROM user_level_engagement_content u
JOIN follower_count f ON u.user_id = f.user_id
),
ranked_advocates AS (
SELECT *,
-- Rank users by advocacy score
DENSE_RANK() OVER(ORDER BY advocacy_score DESC) AS ambassador_rank
FROM brand_advocate_metrics
)

SELECT user_id,followers_count,total_posts,likes_got,comments_got,avg_likes_per_post,avg_comments_per_post,total_engagement,engagement_rate,comment_like_ratio,
influencer_score,consistency_score,advocacy_score,ambassador_rank,
-- Brand ambassador segmentation
CASE
WHEN advocacy_score >= 250 THEN 'Top Brand Ambassador'
WHEN advocacy_score >= 150 THEN 'Potential Brand Advocate'
WHEN advocacy_score >= 80 THEN 'Emerging Influencer'
ELSE 'Regular User'
END AS ambassador_tier,
-- Engagement quality classification
CASE
WHEN comment_like_ratio >= 0.80 THEN 'Highly Interactive Audience'
WHEN comment_like_ratio >= 0.50 THEN 'Moderately Interactive Audience'
ELSE 'Low Interaction Audience'
END AS engagement_quality
FROM ranked_advocates
ORDER BY advocacy_score DESC, engagement_rate DESC;


-- 9 How would you approach this problem, if the objective and subjective questions weren't given?

--  Understand Database Size

-- Total Users
SELECT COUNT(*) AS total_users
FROM users;

-- Total Posts
SELECT COUNT(*) AS total_posts
FROM photos;

-- Total Likes & Comments
SELECT
    (SELECT COUNT(*) FROM likes) AS total_likes,
    (SELECT COUNT(*) FROM comments) AS total_comments;
    
-- User Activity Analysis

-- Most Active Users
SELECT u.id AS user_id,u.username,COUNT(p.id) AS total_posts
FROM users u
LEFT JOIN photos p ON u.id = p.user_id
GROUP BY u.id, u.username
ORDER BY total_posts DESC;

-- Inactive Users
SELECT u.id AS user_id,u.username
FROM users u
LEFT JOIN photos p ON u.id = p.user_id
WHERE p.id IS NULL;

--  Engagement Analysis

-- Most Liked Posts
SELECT photo_id AS photo_id,COUNT(photo_id) AS total_likes
FROM  likes 
GROUP BY photo_id
ORDER BY total_likes DESC;

-- Most Commented Posts
SELECT photo_id AS photo_id,COUNT(photo_id) AS total_comments
FROM  comments 
GROUP BY photo_id
ORDER BY total_comments DESC;

--  Hashtag Trend Analysis
-- Most Used Hashtags
SELECT t.tag_name,COUNT(pt.photo_id) AS total_usage
FROM tags t
JOIN photo_tags pt ON t.id = pt.tag_id
GROUP BY t.tag_name
ORDER BY total_usage DESC;

-- Highest Engagement Hashtags
WITH like_count AS (
SELECT photo_id,COUNT(*) AS total_likes
FROM likes
GROUP BY photo_id
),
comment_count AS (
SELECT photo_id,COUNT(*) AS total_comments
FROM comments
GROUP BY photo_id
)

SELECT t.tag_name,SUM(COALESCE(lc.total_likes,0)) AS likes,SUM(COALESCE(cc.total_comments,0)) AS comments,
SUM(COALESCE(lc.total_likes,0) +COALESCE(cc.total_comments,0)) AS total_engagement
FROM photo_tags pt
JOIN tags t ON pt.tag_id = t.id
LEFT JOIN like_count lc
ON pt.photo_id = lc.photo_id
LEFT JOIN comment_count cc
ON pt.photo_id = cc.photo_id
GROUP BY t.tag_name
ORDER BY total_engagement DESC;

--  Follower Network Analysis
-- Users with Highest Followers
SELECT followee_id AS user_id,COUNT(follower_id) AS followers_count
FROM follows
GROUP BY followee_id
ORDER BY followers_count DESC;

-- Users Following Most People
SELECT follower_id AS user_id,COUNT(followee_id) AS following_count
FROM follows
GROUP BY follower_id
ORDER BY following_count DESC;

--  User Engagement Score
select * from user_level_engagement_content;

-- Influencer Identification
with follower_count as (
select followee_id as user_id,COUNT(follower_id) as followers_count
from follows
group by followee_id
),

influencer_metrics as (
select u.user_id,f.followers_count,u.total_posts,u.likes_got,u.comments_got,
-- Average likes per post
round(coalesce(u.likes_got / u.total_posts,0),2) as avg_likes_per_post,
-- Average comments per post
round(coalesce(u.comments_got / u.total_posts,0),2) as avg_comments_per_post,
-- Total engagement
(u.likes_got + u.comments_got) as total_engagement,
-- Engagement rate
round(((u.likes_got + u.comments_got) * 100.0)/ nullif(f.followers_count,0),2) as engagement_rate,
-- Influencer score
round(((u.likes_got * 0.4) +(u.comments_got * 0.4) +(u.total_posts * 0.2)),2) as influencer_score
from user_level_engagement_content u
join follower_count f on u.user_id = f.user_id
)
select user_id,followers_count,total_posts,likes_got,comments_got,avg_likes_per_post,avg_comments_per_post,total_engagement,engagement_rate,influencer_score
from influencer_metrics
order by influencer_score desc, engagement_rate desc;

--  User Segmentation

with liking_pref as (
SELECT l.user_id,t.tag_name,COUNT(*) as total_likes_on_tag
FROM likes l
JOIN photo_tags pt ON l.photo_id = pt.photo_id
JOIN tags t ON pt.tag_id = t.id
GROUP BY l.user_id, t.tag_name
),

comment_pref as (
SELECT c.user_id,t.tag_name,COUNT(*) as total_comments_on_tag
FROM comments c
JOIN photo_tags pt ON c.photo_id = pt.photo_id
JOIN tags t ON pt.tag_id = t.id
GROUP BY c.user_id, t.tag_name
),

combined_engagement as (
SELECT COALESCE(lp.user_id, cp.user_id) as user_id,COALESCE(lp.tag_name, cp.tag_name) as tag_name,COALESCE(lp.total_likes_on_tag, 0) as total_likes_on_tag,
COALESCE(cp.total_comments_on_tag, 0) as total_comments_on_tag,
(COALESCE(lp.total_likes_on_tag, 0) +COALESCE(cp.total_comments_on_tag, 0)) as engagement_score
FROM liking_pref lp
LEFT JOIN comment_pref cp ON lp.user_id = cp.user_id AND lp.tag_name = cp.tag_name

UNION

SELECT COALESCE(lp.user_id, cp.user_id) as user_id,COALESCE(lp.tag_name, cp.tag_name) as tag_name,COALESCE(lp.total_likes_on_tag, 0) as total_likes_on_tag,
COALESCE(cp.total_comments_on_tag, 0) as total_comments_on_tag,
(COALESCE(lp.total_likes_on_tag, 0) +COALESCE(cp.total_comments_on_tag, 0)) as engagement_score
FROM comment_pref cp
LEFT JOIN liking_pref lp ON lp.user_id = cp.user_id AND lp.tag_name = cp.tag_name
),

ranked_preferences as (
SELECT *,
ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY engagement_score DESC) as rank_num
FROM combined_engagement
)

SELECT user_id,tag_name as dominant_interest,total_likes_on_tag,total_comments_on_tag,engagement_score,
CASE 
WHEN engagement_score >= 80 THEN 'Highly Engaged Users'
WHEN engagement_score >= 40 THEN 'Moderately Engaged Users'
ELSE 'Low Engaged Users'
END AS user_segment,

CASE
WHEN tag_name IN ('food','foodie','delicious') THEN 'Food Lovers'
WHEN tag_name IN ('beach','sunrise','sunset','landscape') THEN 'Travel Enthusiasts'
WHEN tag_name IN ('fashion','style','beauty','hair')THEN 'Fashion Audience'
WHEN tag_name IN ('party','concert','fun','lol')THEN 'Entertainment Audience'
WHEN tag_name IN ('smile','happy','dreamy')THEN 'Lifestyle Audience'
ELSE 'General Users'
END as audience_type
FROM ranked_preferences
WHERE rank_num = 1
ORDER BY engagement_score DESC;

--  Business Insight Query
-- Detect Potential Brand Ambassadors

WITH follower_count AS (
SELECT followee_id AS user_id,COUNT(follower_id) AS followers_count
FROM follows
GROUP BY followee_id
),
brand_advocate_metrics AS (
SELECT u.user_id,f.followers_count,u.total_posts,u.likes_got,u.comments_got,
-- Average likes per post
ROUND(COALESCE(u.likes_got / NULLIF(u.total_posts,0),0),2) AS avg_likes_per_post,
-- Average comments per post
ROUND(COALESCE(u.comments_got / NULLIF(u.total_posts,0),0),2) AS avg_comments_per_post,
-- Total engagement
(u.likes_got + u.comments_got) AS total_engagement,
-- Engagement rate
ROUND(((u.likes_got + u.comments_got) * 100.0) / NULLIF(f.followers_count,0),2) AS engagement_rate,
-- Comment to like ratio
ROUND(COALESCE(u.comments_got / NULLIF(u.likes_got,0),0),2) AS comment_like_ratio,
-- Influencer score
ROUND(((u.likes_got * 0.4) +(u.comments_got * 0.4) +(u.total_posts * 0.2)),2) AS influencer_score,
-- Posting consistency score
ROUND((u.total_posts * 10),2) AS consistency_score,
-- Advocacy score
ROUND((((u.likes_got + u.comments_got) * 0.5) +(u.total_posts * 0.3) +(f.followers_count * 0.2)),2) AS advocacy_score
FROM user_level_engagement_content u
JOIN follower_count f ON u.user_id = f.user_id
),
ranked_advocates AS (
SELECT *,
-- Rank users by advocacy score
DENSE_RANK() OVER(ORDER BY advocacy_score DESC) AS ambassador_rank
FROM brand_advocate_metrics
)

SELECT user_id,followers_count,total_posts,likes_got,comments_got,avg_likes_per_post,avg_comments_per_post,total_engagement,engagement_rate,comment_like_ratio,
influencer_score,consistency_score,advocacy_score,ambassador_rank,
-- Brand ambassador segmentation
CASE
WHEN advocacy_score >= 250 THEN 'Top Brand Ambassador'
WHEN advocacy_score >= 150 THEN 'Potential Brand Advocate'
WHEN advocacy_score >= 80 THEN 'Emerging Influencer'
ELSE 'Regular User'
END AS ambassador_tier,
-- Engagement quality classification
CASE
WHEN comment_like_ratio >= 0.80 THEN 'Highly Interactive Audience'
WHEN comment_like_ratio >= 0.50 THEN 'Moderately Interactive Audience'
ELSE 'Low Interaction Audience'
END AS engagement_quality
FROM ranked_advocates
ORDER BY advocacy_score DESC, engagement_rate DESC;

-- 10 Assuming there's a "User_Interactions" table tracking user engagements, how can you update the "Engagement_Type" column to change all instances of "Like" to "Heart" to align with Instagram's terminology?

UPDATE User_Interactions
SET Engagement_Type = 'Heart'
WHERE Engagement_Type = 'Like';