import { h } from 'preact';
import { articlePropTypes } from '../../common-prop-types';

const isYouTubeEmbed = (url) => {
  try {
    const parsed = new URL(url);
    const host = parsed.hostname.replace(/^www\./, "");
    return (
      ["youtube.com", "youtube-nocookie.com"].includes(host) &&
      parsed.pathname.startsWith("/embed/")
    );
  } catch {
    return false;
  }
};

const normalizeYouTubeEmbedUrl = (url) => {
  try {
    const parsed = new URL(url);
    if (!parsed.pathname.startsWith("/embed/")) {
      return url;
    }

    const [, , videoId] = parsed.pathname.split("/");
    if (!videoId) {
      return url;
    }

    parsed.protocol = "https:";
    parsed.hostname = "www.youtube.com";
    parsed.pathname = `/embed/${videoId}`;

    parsed.searchParams.set("autoplay", "1");
    parsed.searchParams.set("rel", "0");
    parsed.searchParams.set("modestbranding", "1");
    parsed.searchParams.set("playsinline", "1");

    const queryString = parsed.searchParams.toString();
    return `${parsed.origin}${parsed.pathname}${queryString ? `?${queryString}` : ""}`;
  } catch {
    return url;
  }
};

const isMuxEmbed = (url) => {
  try {
    const parsed = new URL(url);
    return parsed.host === "player.mux.com";
  } catch {
    return false;
  }
};

const isTwitchEmbed = (url) => {
  try {
    const parsed = new URL(url);
    return parsed.host === "player.twitch.tv";
  } catch {
    return false;
  }
};

export const Video = ({ article }) => {
  if (isYouTubeEmbed(article.video) || isMuxEmbed(article.video) || isTwitchEmbed(article.video)) {
    // Force 16:9 aspect ratio for YouTube and Mux videos
    return (
      <div
        className="crayons-article__cover crayons-article__cover__image__feed"
        style={{
          width: "100%",
          aspectRatio: "16 / 9",
          position: "relative",
        }}
      >
        <iframe
          src={normalizeYouTubeEmbedUrl(article.video)}
          style={{
            border: 0,
            position: "absolute",
            top: 0,
            left: 0,
            width: "100%",
            height: "100%",
          }}
          allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
          referrerPolicy="strict-origin-when-cross-origin"
          allowFullScreen
          title={article.title}
        />
      </div>
    );
  }
  return (
    <a
      href={article.url}
      className="crayons-story__video"
      style={`background-image:url(${article.cloudinary_video_url})`}
    >
      <span title="Video duration" className="crayons-story__video__time">
        {article.video_duration_in_minutes}
      </span>
    </a>
  );
};

Video.propTypes = {
  article: articlePropTypes.isRequired,
};

Video.displayName = 'Video';
